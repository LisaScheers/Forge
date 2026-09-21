{
  forge.modules.nixos.nook = {pkgs, ...}: let
    python = pkgs.python3.withPackages (ps: [ps.aiohttp]);
    source = ../../../services/watch-room;
    hls = pkgs.fetchurl {
      url = "https://cdn.jsdelivr.net/npm/hls.js@1.6.13/dist/hls.min.js";
      sha256 = "01zv9hmmq5yp3h0c5q4582zg8nnllvcqxp93js6vkrx6sybwsivw";
    };
    hostProxy = {
      proxyPass = "http://unix:/run/watch-room/host.sock:";
      extraConfig = ''
        auth_request /outpost.goauthentik.io/auth/nginx;
        auth_request_set $watch_user $upstream_http_x_authentik_username;
        auth_request_set $watch_cookie $upstream_http_set_cookie;
        add_header Set-Cookie $watch_cookie always;
        proxy_set_header X-Watch-User $watch_user;
        proxy_set_header Authorization "";
      '';
    };
  in {
    security.acme.certs."watch.local.bylisa.dev" = {
      extraLegoFlags = ["--dns.propagation.wait" "30s"];
      group = "nginx";
      reloadServices = ["nginx.service"];
    };
    services.nginx.virtualHosts."watch.local.bylisa.dev" = {
      forceSSL = true;
      useACMEHost = "watch.local.bylisa.dev";
      # Apply the LAN boundary to the console and all SSO endpoints.
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
        proxy_buffers 8 16k;
        proxy_buffer_size 32k;
      '';
      locations."/" =
        hostProxy
        // {
          extraConfig =
            hostProxy.extraConfig
            + ''
              error_page 401 = @watch_signin;
            '';
        };
      # API requests get a 401 so the page can initiate top-level login.
      locations."= /api" = hostProxy;
      locations."@watch_signin".extraConfig = ''
        internal;
        add_header Set-Cookie $watch_cookie always;
        return 302 /outpost.goauthentik.io/start?rd=https://watch.local.bylisa.dev/;
      '';
      locations."/outpost.goauthentik.io/" = {
        proxyPass = "https://auth.bylisa.dev";
        recommendedProxySettings = false;
        extraConfig = ''
          proxy_ssl_server_name on;
          proxy_ssl_name auth.bylisa.dev;
          proxy_ssl_verify on;
          proxy_ssl_verify_depth 3;
          proxy_ssl_trusted_certificate ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt;
          proxy_set_header Host auth.bylisa.dev;
          proxy_set_header X-Forwarded-Host watch.local.bylisa.dev;
          proxy_set_header X-Forwarded-Proto https;
          proxy_set_header X-Original-URL https://watch.local.bylisa.dev$request_uri;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $remote_addr;
          proxy_set_header Authorization "";
          proxy_pass_request_body off;
          proxy_set_header Content-Length "";
        '';
      };
    };
    systemd.services.watch-room = {
      description = "Synchronized private movie screening";
      wantedBy = ["multi-user.target"];
      after = ["network.target"];
      unitConfig.RequiresMountsFor = "/srv/disks/western-digital-hdd/media/library/movies";
      path = [pkgs.ffmpeg];
      environment = {
        WATCH_LIBRARY = "/srv/disks/western-digital-hdd/media/library/movies";
        WATCH_PUBLIC_URL = "https://jellyfin.bylisa.dev";
        WATCH_HLS_JS = "${hls}";
        WATCH_HOST_USER = "lisa";
        WATCH_VAAPI_DEVICE = "/dev/dri/renderD128";
        WATCH_HOST_ORIGIN = "https://watch.local.bylisa.dev";
      };
      serviceConfig = {
        ExecStart = "${python}/bin/python3 ${source}/server.py";
        DynamicUser = true;
        Group = "nginx";
        SupplementaryGroups = ["media" "render"];
        RuntimeDirectory = "watch-room";
        RuntimeDirectoryMode = "0750";
        StateDirectory = "watch-room";
        StateDirectoryMode = "0700";
        UMask = "0077";
        Restart = "on-failure";
        RestartSec = 3;
        NoNewPrivileges = true;
        PrivateTmp = true;
        # Expose only the render node needed by VAAPI.
        PrivateDevices = false;
        DevicePolicy = "closed";
        DeviceAllow = ["/dev/dri/renderD128 rw"];
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
        CPUQuota = "400%";
        TasksMax = 128;
      };
    };
    services.nginx.virtualHosts."jellyfin.bylisa.dev".locations."^~ /watch/" = {
      proxyPass = "http://127.0.0.1:8098";
      extraConfig = ''
        access_log off;
        proxy_buffering off;
        proxy_read_timeout 30s;
      '';
    };
  };
}
