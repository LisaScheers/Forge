{config, ...}: let
  features = config.nixos;
in {
  nixos.atlas = {config, ...}: {
    imports = [features.auto-sync-update];
    services.autoSyncUpdate = {
      enable = true;
      flakeHost = "atlas";
      repositoryPath = "/etc/nix-darwin";
      environmentFile = config.age.secrets.auto-sync-update-env.path;
    };
    age.secrets.auto-sync-update-env = {
      file = ../../security/agenix/secrets/atlas/auto-sync-update-env.age;
      owner = "root";
      group = "root";
      mode = "0400";
    };
  };
  nixos.auto-sync-update = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.autoSyncUpdate;
    defaultScheduleRebootCommand = [
      "/run/current-system/sw/bin/systemd-run"
      "--unit=nix-auto-sync-update-reboot"
      "--description=Reboot after nix-auto-sync-update"
      "--on-active=${toString cfg.rebootDelaySeconds}s"
      "--timer-property=AccuracySec=1min"
      "--collect"
      "/run/current-system/sw/bin/systemctl"
      "reboot"
    ];
    rebuildCommand = lib.concatMapStringsSep " " lib.escapeShellArg cfg.rebuildCommand;
    rebootRequiredCommand =
      lib.optionalString (cfg.rebootRequiredCommand != null)
      (lib.concatMapStringsSep " " lib.escapeShellArg cfg.rebootRequiredCommand);
    scheduleRebootCommand = lib.concatMapStringsSep " " lib.escapeShellArg (
      if cfg.scheduleRebootCommand != null
      then cfg.scheduleRebootCommand
      else defaultScheduleRebootCommand
    );
    hasCustomScheduleRebootCommand = cfg.scheduleRebootCommand != null;
    # Percent-encoded per path segment for the git+file URL.
    encodedRepositoryPath = lib.concatMapStringsSep "/" lib.strings.escapeURL (lib.splitString "/" cfg.repositoryPath);
    script = pkgs.writeShellApplication {
      name = "nix-auto-sync-update";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.curl
        pkgs.git
        pkgs.openssh
        pkgs.util-linux
      ];
      # The configured values; the logic lives in update.sh.
      text =
        ''
          set -euo pipefail
          repo_path=${lib.escapeShellArg cfg.repositoryPath}
          repo_url=${lib.escapeShellArg "git+file://${encodedRepositoryPath}"}
          flake_host=${lib.escapeShellArg cfg.flakeHost}
          branch=${lib.escapeShellArg cfg.branch}
          lock_path=${lib.escapeShellArg cfg.lockPath}
          email_to=${lib.escapeShellArg cfg.emailTo}
          mail_host=${lib.escapeShellArg config.networking.fqdnOrHostName}
          reboot_delay_seconds=${toString cfg.rebootDelaySeconds}
          custom_reboot_required=${lib.escapeShellArg (lib.boolToString (cfg.rebootRequiredCommand != null))}
          custom_schedule_reboot=${lib.escapeShellArg (lib.boolToString hasCustomScheduleRebootCommand)}
          rebuild_cmd=(${rebuildCommand})
          reboot_required_cmd=(${rebootRequiredCommand})
          schedule_reboot_cmd=(${scheduleRebootCommand})
        ''
        + builtins.readFile ./update.sh;
    };
  in {
    options.services.autoSyncUpdate = {
      enable = (lib.mkEnableOption "automatic repository sync and host rebuild") // {default = true;};

      flakeHost = lib.mkOption {
        type = lib.types.str;
        description = "Flake output host name to switch after the repository is pulled.";
      };

      repositoryPath = lib.mkOption {
        type = lib.types.str;
        description = "Local checkout path for this repository.";
      };

      branch = lib.mkOption {
        type = lib.types.str;
        default = "main";
        description = "Git branch to fast-forward and apply.";
      };

      environmentFile = lib.mkOption {
        type = lib.types.str;
        default = "/etc/nix-auto-sync-update.env";
        description = "Optional KEY=value file with Git and SMTP credentials, loaded by systemd (EnvironmentFile=).";
      };

      emailTo = lib.mkOption {
        type = lib.types.str;
        default = "lisa@scheers.tech";
        description = "Default watchdog email recipient.";
      };

      intervalSeconds = lib.mkOption {
        type = lib.types.ints.positive;
        default = 3000;
        description = "Number of seconds between sync attempts.";
      };

      rebootDelaySeconds = lib.mkOption {
        type = lib.types.ints.positive;
        default = 43200;
        description = "Number of seconds to wait before rebooting after an update that requires a reboot.";
      };

      lockPath = lib.mkOption {
        type = lib.types.str;
        default = "/var/run/nix-auto-sync-update.lock";
        description = "Advisory lock file that prevents overlapping runs.";
      };

      rebuildCommand = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = ["/run/current-system/sw/bin/nixos-rebuild" "switch"];
        description = "Command used to switch the host after pulling the repository.";
      };

      rebootRequiredCommand = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf lib.types.str);
        default = null;
        description = "Optional command that exits 0 when a reboot should be scheduled.";
      };

      scheduleRebootCommand = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf lib.types.str);
        default = null;
        description = "Optional command used to schedule the delayed reboot.";
      };
    };

    config = lib.mkIf cfg.enable {
      systemd.services.nix-auto-sync-update = {
        description = "Pull this Nix repository and apply host changes";
        restartIfChanged = false;
        stopIfChanged = false;
        wants = ["network-online.target"];
        after = ["network-online.target"];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = lib.getExe script;
          # "-" makes the file optional.
          EnvironmentFile = "-${cfg.environmentFile}";
        };
      };

      systemd.timers.nix-auto-sync-update = {
        description = "Run nix-auto-sync-update periodically";
        wantedBy = ["timers.target"];
        timerConfig = {
          OnActiveSec = "${toString cfg.intervalSeconds}s";
          OnUnitActiveSec = "${toString cfg.intervalSeconds}s";
          AccuracySec = "30s";
          Unit = "nix-auto-sync-update.service";
        };
      };
    };
  };
}
