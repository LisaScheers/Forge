{
  forge.modules.nixos.nook = {pkgs, ...}: let
    python = pkgs.python3.withPackages (ps: [ps.aiohttp]);
    source = ../../../services/watch-room;
    hls = pkgs.fetchurl {
      url = "https://cdn.jsdelivr.net/npm/hls.js@1.6.13/dist/hls.min.js";
      sha256 = "01zv9hmmq5yp3h0c5q4582zg8nnllvcqxp93js6vkrx6sybwsivw";
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
      locations."/" = {
        proxyPass = "http://127.0.0.1:8099";
        # A local DNS name alone does not prevent access through the WAN.
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
      };
      serviceConfig = {
        ExecStart = "${python}/bin/python3 ${source}/server.py";
        DynamicUser = true;
        SupplementaryGroups = ["media"];
        StateDirectory = "watch-room";
        StateDirectoryMode = "0700";
        UMask = "0077";
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
