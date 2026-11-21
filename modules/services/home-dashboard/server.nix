{
  config,
  lib,
  ...
}: let
  tree = ../../../services/home-dashboard;
  source = config.flake.lib.runtimeSource tree;
  # The catalog is read at runtime, so check here that every IPv4 address in
  # its URLs and probe addresses is one of Nook's (or loopback).
  catalog = builtins.fromJSON (builtins.readFile (tree + "/catalog.json"));
  hostOf = url: let
    match = builtins.match "[A-Za-z][A-Za-z0-9+.-]*://([^@/?#]*@)?([^/:?#]+).*" url;
  in
    if match == null
    then null
    else builtins.elemAt match 1;
  endpoints = entry: map hostOf (lib.filter (url: url != null) [(entry.url or null) (entry.probe.url or null)]) ++ [(entry.probe.address or null)];
  isIPv4 = host: host != null && builtins.match "[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+" host != null;
  catalogAddresses = lib.unique (lib.filter isIPv4 (lib.concatMap endpoints catalog));
  # Userinfo, scheme case and an "@" after the authority must not hide an address.
  parsesHosts =
    map hostOf ["HTTP://user@10.0.0.1:8123/x" "http://10.0.0.2?x=@a.example" "http://10.0.0.3#@b" "https://a.example?b" "tcp://192.0.2.1"]
    == ["10.0.0.1" "10.0.0.2" "10.0.0.3" "a.example" "192.0.2.1"];
  staleAddresses = lib.subtractLists ["127.0.0.1" config.network.nook.lan config.network.nook.tailscale] catalogAddresses;
in {
  perSystem = {pkgs, ...}: {
    checks.home-dashboard = assert lib.assertMsg parsesHosts "home-dashboard catalog URL parsing is broken";
    assert lib.assertMsg (staleAddresses == []) "home-dashboard catalog.json has addresses not in network.nook: ${toString staleAddresses}";
      pkgs.runCommand "home-dashboard-tests" {} ''
        ${pkgs.python3}/bin/python3 -B -m unittest discover -s ${tree} -v
        touch "$out"
      '';
  };
  nixos.atlas = {pkgs, ...}: let
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
