let
  domain = "ai.local.bylisa.dev";
  source = ../../../services/ai-archive;
in {
  perSystem = {pkgs, ...}: {
    packages.ai-archive-auth-blueprint = pkgs.writeText "ai-archive.yaml" (builtins.readFile (source + /authentik.yaml));
    checks.ai-archive = pkgs.runCommand "ai-archive-tests" {} ''
      ${pkgs.python3.withPackages (ps: [ps.aiohttp])}/bin/python3 -B -m unittest discover -s ${source} -v
      ${pkgs.nodejs}/bin/node --check ${source}/public/app.js
      touch "$out"
    '';
  };
  nixos.nook = {
    config,
    pkgs,
    ...
  }: let
    upstream = "http://unix:/run/ai-archive/http.sock:";
    protected = ''
      auth_request /outpost.goauthentik.io/auth/nginx;
      auth_request_set $archive_user $upstream_http_x_authentik_username;
      auth_request_set $archive_cookie $upstream_http_set_cookie;
      add_header Set-Cookie $archive_cookie always;
      add_header Cache-Control "private, no-store" always;
      proxy_set_header X-AI-User $archive_user;
      proxy_set_header Authorization "";
      proxy_set_header Cookie "";
      proxy_read_timeout 120s;
    '';
  in {
    systemd.services.ai-archive = {
      description = "Private AI conversation archive and token analytics";
      wantedBy = ["multi-user.target"];
      after = ["ai-usage-schema.service"];
      requires = ["ai-usage-schema.service"];
      unitConfig.RequiresMountsFor = ["/srv/disks/projects"];
      serviceConfig = {
        ExecStart = "${pkgs.python3.withPackages (ps: [ps.aiohttp])}/bin/python3 ${source}/server.py";
        EnvironmentFile = "/srv/disks/projects/ai-usage-secrets/clickhouse.env";
        DynamicUser = true;
        Group = "nginx";
        StateDirectory = "ai-archive";
        StateDirectoryMode = "0700";
        RuntimeDirectory = "ai-archive";
        RuntimeDirectoryMode = "0750";
        UMask = "0007";
        Restart = "on-failure";
        RestartSec = 3;
        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        RestrictAddressFamilies = ["AF_UNIX" "AF_INET"];
        IPAddressDeny = "any";
        IPAddressAllow = "localhost";
        MemoryMax = "2G";
        TasksMax = 64;
      };
    };
    security.acme.certs.${domain} = {
      extraLegoFlags = ["--dns.propagation.wait" "30s"];
      group = "nginx";
      reloadServices = ["nginx.service"];
    };
    services.nginx.virtualHosts.${domain} = {
      forceSSL = true;
      useACMEHost = domain;
      extraConfig = ''
        allow 127.0.0.1;
        allow ::1;
        allow 192.168.50.0/24;
        allow 192.168.111.0/24;
        allow 2a02:1810:515:c680::/64;
        allow 2a02:1810:515:c682::/64;
        allow 100.64.0.0/10;
        allow fd7a:115c:a1e0::/48;
        deny all;
        access_log off;
        client_max_body_size 1m;
        proxy_buffers 8 16k;
        proxy_buffer_size 32k;
      '';
      locations."/" = {
        proxyPass = upstream;
        extraConfig =
          protected
          + ''
            error_page 401 = @archive_signin;
          '';
      };
      locations."/api/" = {
        proxyPass = upstream;
        extraConfig = protected;
      };
      locations."@archive_signin".extraConfig = ''
        internal;
        add_header Set-Cookie $archive_cookie always;
        return 302 /outpost.goauthentik.io/start?rd=https://${domain}/;
      '';
      locations."^~ /outpost.goauthentik.io/" = {
        proxyPass = "https://auth.bylisa.dev";
        recommendedProxySettings = false;
        extraConfig = ''
          proxy_ssl_server_name on;
          proxy_ssl_name auth.bylisa.dev;
          proxy_ssl_verify on;
          proxy_ssl_verify_depth 3;
          proxy_ssl_trusted_certificate ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt;
          proxy_set_header Host auth.bylisa.dev;
          proxy_set_header X-Forwarded-Host ${domain};
          proxy_set_header X-Forwarded-Proto https;
          proxy_set_header X-Original-URL https://${domain}$request_uri;
          proxy_set_header X-Original-URI "";
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $remote_addr;
          proxy_set_header Authorization "";
          proxy_pass_request_body off;
          proxy_set_header Content-Length "";
        '';
      };
    };
  };
  nixos.atlas = {
    config,
    pkgs,
    ...
  }: {
    systemd.services.authentik-ai-archive-blueprint = {
      description = "Apply AI Archive's Lisa-only Authentik provider";
      wantedBy = ["multi-user.target"];
      requiredBy = ["authentik.service"];
      before = ["authentik.service"];
      after = ["authentik-migrate.service"];
      requires = ["authentik-migrate.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        DynamicUser = true;
        User = "authentik";
        StateDirectory = "authentik";
        WorkingDirectory = "%S/authentik";
        EnvironmentFile = [config.age.secrets.authentik-env.path];
        Environment = ["AUTHENTIK_CONFIG=/etc/authentik/config.yml"];
        ExecStartPre = "${pkgs.coreutils}/bin/install -D -m 0600 ${source}/authentik.yaml %S/authentik/blueprints/ai-archive.yaml";
        ExecStart = "${config.services.authentik.authentikComponents.manage}/bin/manage.py apply_blueprint ai-archive.yaml";
        ExecStartPost = ''${config.services.authentik.authentikComponents.manage}/bin/manage.py shell -c "from authentik.outposts.models import Outpost; from authentik.providers.proxy.models import ProxyProvider; outpost = Outpost.objects.get(managed='goauthentik.io/outposts/embedded'); outpost.providers.add(ProxyProvider.objects.get(name='AI Archive')); outpost.save()"'';
      };
      restartTriggers = [(source + /authentik.yaml)];
    };
  };
}
