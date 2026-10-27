{config, ...}: let
  repositoryRoot = "/srv/disks/western-digital-hdd/backups/atlas-matrix";
  nookKey = config.secrets.pubkeys.hosts.nook;
in {
  nixos.nook = {pkgs, ...}: {
    users.groups.matrix-backup = {};
    users.users.matrix-backup = {
      isSystemUser = true;
      group = "matrix-backup";
      home = "/repository";
      shell = "${pkgs.shadow}/bin/nologin";
      openssh.authorizedKeys.keys = [
        ''from="100.87.26.75",restrict ${builtins.readFile ./backup.pub}''
      ];
    };
    systemd.services.matrix-backup-repository = {
      description = "Prepare the Matrix backup repository on Nook's mounted HDD";
      wantedBy = ["multi-user.target"];
      unitConfig.RequiresMountsFor = repositoryRoot;
      path = [pkgs.coreutils pkgs.util-linux];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        mountpoint -q /srv/disks/western-digital-hdd
        install -d -m 0755 /srv/disks/western-digital-hdd/backups ${repositoryRoot}
        install -d -m 0700 -o matrix-backup -g matrix-backup ${repositoryRoot}/repository
      '';
    };
    services.openssh.extraConfig = ''
      Match User matrix-backup
        ChrootDirectory ${repositoryRoot}
        ForceCommand internal-sftp -u 0077
        DisableForwarding yes
        PermitTTY no
      Match all
    '';
  };

  nixos.atlas = {
    config,
    lib,
    pkgs,
    ...
  }: let
    python = pkgs.python3.withPackages (ps: [ps.pyyaml]);
    resume = pkgs.writeShellApplication {
      name = "matrix-backup-resume";
      runtimeInputs = [pkgs.coreutils pkgs.systemd];
      text = builtins.readFile ./backup-resume.sh;
    };
    sshConfig = pkgs.writeText "matrix-backup-ssh-config" ''
      Host matrix-backup
        HostName 100.106.233.104
        User matrix-backup
        IdentityFile ${config.age.secrets.matrix-backup-ssh-key.path}
        IdentitiesOnly yes
        BatchMode yes
        StrictHostKeyChecking yes
        UserKnownHostsFile ${pkgs.writeText "matrix-backup-known-hosts" "100.106.233.104 ${nookKey}\n"}
        GlobalKnownHostsFile /dev/null
        ServerAliveInterval 30
        ServerAliveCountMax 6
    '';
    prepare = pkgs.writeShellApplication {
      name = "matrix-backup-prepare";
      runtimeInputs = [pkgs.coreutils pkgs.findutils pkgs.rsync pkgs.util-linux pkgs.systemd pkgs.sudo config.services.postgresql.package];
      runtimeEnv.SYNAPSE_CONFIG = pkgs.writeText "matrix-backup-synapse-config.json" (builtins.toJSON config.services.matrix-synapse.settings);
      runtimeEnv.RESUME_COMMAND = lib.getExe resume;
      runtimeEnv.MEDIA_COPY_COMMAND = lib.getExe (pkgs.writeShellApplication {
        name = "matrix-backup-copy-media";
        runtimeInputs = [pkgs.rsync];
        text = builtins.readFile ./backup-copy-media.sh;
      });
      runtimeEnv.PLURAL_ENABLED =
        if config.matrix.plural.enable
        then "1"
        else "0";
      runtimeEnv.MEDIA_RSYNC_SSH = lib.optionalString config.matrix.remoteMedia.enable "${pkgs.openssh}/bin/ssh -F ${sshConfig} -l matrix-media";
      runtimeEnv.PLURAL_CONFIG =
        pkgs.writeText "matrix-backup-plural-config.json"
        (builtins.toJSON (
          if config.matrix.plural.enable
          then config.systemd.services.pluralmatrix.environment
          else {}
        ));
      text = builtins.readFile ./backup-prepare.sh;
    };
    prepareRestore = pkgs.writeShellApplication {
      name = "matrix-restore-prepare";
      runtimeInputs = [pkgs.coreutils];
      text = ''
        test -f /var/lib/matrix-restore-input/var/backup/matrix-coordinated/COMPLETE
        rm -rf /var/lib/matrix-restore-check/input /var/lib/matrix-restore-check/work
        # DynamicUser's id-mapped mount cannot represent production service UIDs.
        cp -a --no-preserve=ownership /var/lib/matrix-restore-input/var/backup/matrix-coordinated /var/lib/matrix-restore-check/input
        # The enclosing StateDirectory remains 0700 and belongs to DynamicUser.
        chmod -R a+rX /var/lib/matrix-restore-check/input
      '';
    };
  in
    lib.mkIf config.matrix.discord.enable {
      age.secrets = {
        matrix-backup-password = {
          file = ../../security/agenix/secrets/atlas/matrix-backup-password.age;
          mode = "0400";
        };
        matrix-backup-ssh-key = {
          file = ../../security/agenix/secrets/atlas/matrix-backup-ssh-key.age;
          mode = "0400";
        };
      };
      services.restic.backups.matrix = {
        repository = "sftp:matrix-backup:/repository";
        passwordFile = config.age.secrets.matrix-backup-password.path;
        initialize = true;
        paths = ["/var/backup/matrix-coordinated"];
        extraOptions = ["sftp.command='${pkgs.openssh}/bin/ssh -F ${sshConfig} matrix-backup -s sftp'"];
        backupPrepareCommand = "${lib.getExe prepare}";
        backupCleanupCommand = "${lib.getExe resume}";
        runCheck = true;
        timerConfig = {
          OnCalendar = "*-*-* 02:00:00";
          Persistent = true;
        };
        # Retention/deletion is a separate decision; preserve every snapshot.
      };
      systemd.services.restic-backups-matrix = {
        after = ["postgresql.service" "tailscaled.service"];
        requires = ["postgresql.service"];
        serviceConfig = {
          UMask = "0077";
          TimeoutStartSec =
            if config.matrix.remoteMedia.enable
            then "2h"
            else "1h";
          CPUWeight = 25;
          IOWeight = 25;
        };
      };
      systemd.services.nix-auto-sync-update.serviceConfig.ExecCondition = [
        "${pkgs.coreutils}/bin/test ! -e /run/matrix-coordinated-state"
      ];
      systemd.services.matrix-restore-check = {
        description = "Verify a separate Matrix restore without external network access";
        path =
          [config.services.postgresql.package config.services.matrix-synapse.package config.services.mautrix-discord.package]
          ++ lib.optional config.matrix.plural.enable pkgs.pluralmatrix;
        serviceConfig = {
          Type = "oneshot";
          DynamicUser = true;
          StateDirectory = "matrix-restore-check";
          StateDirectoryMode = "0700";
          WorkingDirectory = "/var/lib/matrix-restore-check";
          ExecStartPre = "+${lib.getExe prepareRestore}";
          ExecStart = "${lib.getExe python} ${./restore-check.py}";
          PrivateNetwork = true;
          PrivateTmp = true;
          PrivateDevices = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          NoNewPrivileges = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectControlGroups = true;
          RestrictSUIDSGID = true;
          RestrictNamespaces = true;
          InaccessiblePaths =
            ["/run/postgresql" "/run/agenix" "/var/lib/postgresql" "/var/lib/matrix-synapse" "/var/lib/mautrix-discord"]
            ++ lib.optionals config.matrix.plural.enable ["/var/lib/pluralmatrix" "/var/lib/pluralmatrix-registration"];
          UMask = "0077";
          TimeoutStartSec = "30min";
          CPUWeight = 10;
          IOWeight = 10;
          MemoryMax = "4G";
        };
      };
    };
}
