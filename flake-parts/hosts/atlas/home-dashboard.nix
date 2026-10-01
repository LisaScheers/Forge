{
  forge.modules.nixos.atlas = {
    config,
    pkgs,
    ...
  }: let
    source = ../../../services/home-dashboard;
    upstream = "http://unix:/run/home-dashboard/api.sock:";
    securityHeaders = ''
      add_header X-Content-Type-Options nosniff always;
      add_header Referrer-Policy same-origin always;
      add_header Content-Security-Policy "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self'; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'" always;
    '';
    protectedProxy = {
      proxyPass = upstream;
      recommendedProxySettings = false;
      extraConfig = ''
        auth_request /outpost.goauthentik.io/auth/nginx;
        auth_request_set $dash_user $upstream_http_x_authentik_username;
        auth_request_set $dash_cookie $upstream_http_set_cookie;
        add_header Set-Cookie $dash_cookie always;
        add_header Cache-Control "private, no-store" always;
        proxy_set_header X-Dashboard-User $dash_user;
        proxy_set_header Authorization "";
        ${securityHeaders}
      '';
    };
  in {
    systemd.services.home-dashboard = {
      description = "Home service dashboard API";
      wantedBy = ["multi-user.target"];
      after = ["home-dashboard-status.service"];
      wants = ["home-dashboard-status.service"];
      serviceConfig = {
        ExecStart = "${pkgs.python3}/bin/python3 ${source}/server.py";
        DynamicUser = true;
        Group = "nginx";
        RuntimeDirectory = "home-dashboard";
        RuntimeDirectoryMode = "0750";
        UMask = "0007";
        Restart = "on-failure";
        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        RestrictAddressFamilies = ["AF_UNIX"];
      };
    };
    systemd.services.home-dashboard-status = {
      description = "Read-only Kuma status export and dashboard reachability checks";
      after = ["uptime-kuma.service" "network-online.target"];
      wants = ["network-online.target"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.python3}/bin/python3 ${source}/collect.py";
        Group = "nginx";
        StateDirectory = "home-dashboard-status";
        StateDirectoryMode = "0750";
        UMask = "0027";
        TimeoutStartSec = 45;
        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        ReadOnlyPaths = ["/var/lib/uptime-kuma"];
        RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6"];
      };
    };
    systemd.timers.home-dashboard-status = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "30s";
        OnUnitInactiveSec = "30s";
        AccuracySec = "1s";
      };
    };

    systemd.services.authentik-home-dashboard-blueprint = {
      description = "Apply the dashboard Authentik provider";
      requiredBy = ["authentik.service"];
      before = ["authentik.service"];
      after = ["authentik-migrate.service"];
      requires = ["authentik-migrate.service"];
      serviceConfig = {
        Type = "oneshot";
        DynamicUser = true;
        User = "authentik";
        StateDirectory = "authentik";
        WorkingDirectory = "%S/authentik";
        EnvironmentFile = [config.age.secrets.authentik-env.path];
        Environment = ["AUTHENTIK_CONFIG=/etc/authentik/config.yml"];
        ExecStartPre = "${pkgs.coreutils}/bin/install -D -m 0600 ${source}/authentik.yaml %S/authentik/blueprints/home-dashboard.yaml";
        ExecStart = "${config.services.authentik.authentikComponents.manage}/bin/manage.py apply_blueprint home-dashboard.yaml";
        ExecStartPost = ''${config.services.authentik.authentikComponents.manage}/bin/manage.py shell -c "from authentik.outposts.models import Outpost; from authentik.providers.proxy.models import ProxyProvider; outpost = Outpost.objects.get(managed='goauthentik.io/outposts/embedded'); outpost.providers.add(ProxyProvider.objects.get(name='Home dashboard')); outpost.save()"'';
      };
      restartTriggers = [../../agenix/secrets/atlas/authentik-env.age];
    };

    services.nginx.virtualHosts."dash.bylisa.dev" = {
      enableACME = true;
      forceSSL = true;
      root = "${source}/public";
      extraConfig = ''
        proxy_buffers 8 16k;
        proxy_buffer_size 32k;
        ${securityHeaders}
      '';
      locations."/".extraConfig = ''
        try_files $uri $uri/ =404;
      '';
      locations."= /api/public" = {
        proxyPass = upstream;
        recommendedProxySettings = false;
        extraConfig = ''
          proxy_set_header X-Dashboard-User "";
          proxy_set_header Authorization "";
          add_header Cache-Control "no-store" always;
          ${securityHeaders}
        '';
      };
      locations."= /api/private" = protectedProxy;
      locations."= /login" =
        protectedProxy
        // {
          extraConfig =
            protectedProxy.extraConfig
            + ''
              error_page 401 = @dash_signin;
            '';
        };
      locations."@dash_signin".extraConfig = ''
        internal;
        add_header Set-Cookie $dash_cookie always;
        ${securityHeaders}
        return 302 /outpost.goauthentik.io/start?rd=https://dash.bylisa.dev/login;
      '';
      locations."^~ /outpost.goauthentik.io/" = {
        proxyPass = "https://127.0.0.1:9443";
        recommendedProxySettings = false;
        extraConfig = ''
          proxy_set_header Host dash.bylisa.dev;
          proxy_set_header X-Forwarded-Host dash.bylisa.dev;
          proxy_set_header X-Forwarded-Proto https;
          proxy_set_header X-Original-URL https://dash.bylisa.dev$request_uri;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $remote_addr;
          proxy_set_header Authorization "";
          proxy_pass_request_body off;
          proxy_set_header Content-Length "";
        '';
      };
    };
  };
}
