{...}: {
  nixos.matrix-volume = {
    config,
    lib,
    pkgs,
    utils,
    ...
  }: let
    cfg = config.matrix.volume;
    media = "${config.services.matrix-synapse.dataDir}/media_store";
    recovery = "/var/backup/matrix-coordinated";
    diskUnit = "${utils.escapeSystemdPath cfg.mountPoint}.mount";
    mediaUnit = "${utils.escapeSystemdPath media}.mount";
    recoveryUnit = "${utils.escapeSystemdPath recovery}.mount";
    requireDisk = pkgs.writeShellScript "require-matrix-volume" ''
      set -euo pipefail
      test "$(${pkgs.util-linux}/bin/findmnt -nro FSTYPE -M ${lib.escapeShellArg cfg.mountPoint} | ${pkgs.coreutils}/bin/sort -u)" = ext4
      actual=$(${pkgs.util-linux}/bin/findmnt -nro SOURCE -M ${lib.escapeShellArg cfg.mountPoint} | ${pkgs.coreutils}/bin/sort -u)
      test "$(${pkgs.coreutils}/bin/readlink -f "$actual")" = "$(${pkgs.coreutils}/bin/readlink -f ${lib.escapeShellArg cfg.device})"
      test "$(${pkgs.coreutils}/bin/cat ${lib.escapeShellArg "${cfg.mountPoint}/.matrix-volume"})" = atlas-matrix-volume-v1
    '';
    requireMedia = pkgs.writeShellScript "require-matrix-volume-media" ''
      set -euo pipefail
      ${requireDisk}
      # Synapse adds a sandbox bind mount; every stacked entry must agree.
      uuid=$(${pkgs.util-linux}/bin/findmnt -nro UUID -M ${lib.escapeShellArg cfg.mountPoint} | ${pkgs.coreutils}/bin/sort -u)
      test -n "$uuid"
      test "$(${pkgs.util-linux}/bin/findmnt -nro UUID -M ${lib.escapeShellArg media} | ${pkgs.coreutils}/bin/sort -u)" = "$uuid"
      test "$(${pkgs.util-linux}/bin/findmnt -nro FSTYPE -M ${lib.escapeShellArg media} | ${pkgs.coreutils}/bin/sort -u)" = ext4
      test "$(${pkgs.util-linux}/bin/findmnt -nro FSROOT -M ${lib.escapeShellArg media} | ${pkgs.coreutils}/bin/sort -u)" = /media_store
    '';
    requireRecovery = pkgs.writeShellScript "require-matrix-volume-recovery" ''
      set -euo pipefail
      ${requireMedia}
      test "$(${pkgs.util-linux}/bin/findmnt -nro UUID -M ${recovery} | ${pkgs.coreutils}/bin/sort -u)" = "$(${pkgs.util-linux}/bin/findmnt -nro UUID -M ${lib.escapeShellArg cfg.mountPoint} | ${pkgs.coreutils}/bin/sort -u)"
      test "$(${pkgs.util-linux}/bin/findmnt -nro FSTYPE -M ${recovery} | ${pkgs.coreutils}/bin/sort -u)" = ext4
      test "$(${pkgs.util-linux}/bin/findmnt -nro FSROOT -M ${recovery} | ${pkgs.coreutils}/bin/sort -u)" = /recovery
    '';
    bind = source: target: {
      what = "${cfg.mountPoint}/${source}";
      where = target;
      type = "none";
      options = "bind,nodev,nosuid,noexec";
      wantedBy = ["multi-user.target"];
      requires = ["matrix-volume-layout.service"];
      after = ["matrix-volume-layout.service"];
      bindsTo = [diskUnit];
    };
  in {
    options.matrix.volume = {
      enable = lib.mkEnableOption "Atlas's dedicated Matrix storage volume";
      device = lib.mkOption {type = lib.types.str;};
      mountPoint = lib.mkOption {
        type = lib.types.str;
        default = "/srv/matrix";
      };
    };
    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = config.services.matrix-synapse.enable && !(config.matrix.remoteMedia.enable or false);
          message = "The Matrix volume requires Synapse and replaces remote media storage";
        }
      ];
      fileSystems.${cfg.mountPoint} = {
        device = cfg.device;
        fsType = "ext4";
        options = ["nofail" "nodev" "nosuid" "noexec" "x-systemd.device-timeout=30s"];
      };
      systemd.services.matrix-volume-layout = {
        description = "Require the initialized Matrix volume and prepare its directories";
        # Bind mounts precede local-fs.target, so preparation cannot wait for basic.target.
        unitConfig.DefaultDependencies = false;
        requires = [diskUnit];
        after = [diskUnit];
        bindsTo = [diskUnit];
        before = ["shutdown.target"];
        conflicts = ["shutdown.target"];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStartPre = requireDisk;
        };
        script = ''
          ${pkgs.coreutils}/bin/chmod 0711 ${lib.escapeShellArg cfg.mountPoint}
          ${pkgs.coreutils}/bin/install -d -m 0700 -o matrix-synapse -g matrix-synapse ${lib.escapeShellArg "${cfg.mountPoint}/media_store"}
          ${pkgs.coreutils}/bin/install -d -m 0700 -o root -g root ${lib.escapeShellArg "${cfg.mountPoint}/recovery"}
        '';
      };
      systemd.mounts = [(bind "media_store" media) (bind "recovery" recovery)];
      services.matrix-synapse.settings = {
        media_store_path = media;
        max_upload_size = "512M";
      };
      systemd.services.matrix-synapse = {
        requires = [mediaUnit];
        after = [mediaUnit];
        bindsTo = [mediaUnit diskUnit];
        # The device identity is hidden by Synapse's PrivateDevices sandbox.
        serviceConfig.ExecStartPre = ["+${requireMedia}"];
      };
      systemd.services.restic-backups-matrix = {
        requires = [mediaUnit recoveryUnit];
        after = [mediaUnit recoveryUnit];
        bindsTo = [diskUnit recoveryUnit];
        serviceConfig.ExecStartPre = [requireRecovery];
      };
    };
  };
}
