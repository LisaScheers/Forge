{
  forge.modules.nixos.nook = {pkgs, ...}: let
    sunshineCheck = pkgs.writeShellApplication {
      name = "home-dashboard-sunshine-check";
      runtimeInputs = [pkgs.coreutils pkgs.netcat-openbsd];
      text = ''
        service_state=down
        if nc -z -w 3 192.168.111.2 47990; then
          service_state=up
        fi
        printf '{"generated":%s,"status":"%s"}\n' "$(date +%s)" "$service_state" \
          > /var/lib/home-dashboard-checks/sunshine.tmp
        chmod 0640 /var/lib/home-dashboard-checks/sunshine.tmp
        mv /var/lib/home-dashboard-checks/sunshine.tmp /var/lib/home-dashboard-checks/sunshine.json
      '';
    };
  in {
    # Only Atlas can read this status file, over the existing Tailscale path.
    services.nginx.virtualHosts."jellyfin.bylisa.dev".locations."= /.dashboard/sunshine.json".extraConfig = ''
      allow 100.87.26.75;
      deny all;
      alias /var/lib/home-dashboard-checks/sunshine.json;
      default_type application/json;
      add_header Cache-Control "no-store" always;
    '';
    systemd.services.home-dashboard-sunshine-check = {
      description = "Check the LAN-only Sunshine listener for the home dashboard";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${sunshineCheck}/bin/home-dashboard-sunshine-check";
        DynamicUser = true;
        Group = "nginx";
        StateDirectory = "home-dashboard-checks";
        StateDirectoryMode = "0750";
        UMask = "0027";
        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        RestrictAddressFamilies = ["AF_INET" "AF_UNIX"];
      };
    };
    systemd.timers.home-dashboard-sunshine-check = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "30s";
        OnUnitInactiveSec = "30s";
        AccuracySec = "1s";
      };
    };
  };
}
