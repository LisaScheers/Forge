{
  nixos.nook = {
    lib,
    pkgs,
    ...
  }: let
    minecraftRoot = "/srv/disks/second-life-cache/minecraft";
    servers = {
      atm10-aero = {
        directory = "${minecraftRoot}/atm10-aero-0.7.1";
        description = "All the Mods 10 Aeronautics 0.7.1";
        launcher = "startserver.sh";
      };
      ftb-skies-2-aero = {
        directory = "${minecraftRoot}/ftb-skies-2-aero-1.13.0";
        description = "FTB Skies 2: Aero 1.13.0";
        launcher = "run.sh";
      };
    };
  in {
    users.groups = lib.mapAttrs (_: _: {}) servers;
    users.users =
      lib.mapAttrs (name: server: {
        isSystemUser = true;
        group = name;
        home = server.directory;
      })
      servers;

    services.cloudflare-dyndns.domains = ["mc.bylisa.dev"];
    networking.firewall.allowedTCPPorts = [25565];

    systemd.services =
      lib.mapAttrs (name: server: {
        description = "${server.description} Minecraft server";
        # Prepared services are manual-only; neither starts on boot or activation.
        wantedBy = [];
        unitConfig = {
          RequiresMountsFor = server.directory;
          Conflicts = map (other: "${other}.service") (lib.filter (other: other != name) (builtins.attrNames servers));
          ConditionPathExists = "${server.directory}/.prepared";
        };
        path = with pkgs; [coreutils curl gawk jdk21_headless wget];
        environment = {
          JAVA_HOME = "${pkgs.jdk21_headless}";
          ATM10_JAVA = "${pkgs.jdk21_headless}/bin/java";
          ATM10_RESTART = "false";
        };
        script = ''
          exec ${pkgs.bash}/bin/bash ./${server.launcher}
        '';
        serviceConfig = {
          User = name;
          Group = name;
          WorkingDirectory = server.directory;
          NoNewPrivileges = true;
          Restart = "on-failure";
          RestartSec = "30s";
          KillSignal = "SIGINT";
          TimeoutStopSec = "120s";
          MemoryHigh = "18G";
          MemoryMax = "20G";
        };
      })
      servers;
  };
}
