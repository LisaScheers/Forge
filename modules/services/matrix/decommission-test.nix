{
  config,
  inputs,
  lib,
  ...
}: let
  atlas = config.flake.nixosConfigurations.atlas.config;
  nook = config.flake.nixosConfigurations.nook.config;
  pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
  sharedCredentials = ["discord-bridge-env" "matrix-backup-password" "matrix-backup-ssh-key"];
  checks = {
    dmBridgePreserved = atlas.matrix.discord.enable && atlas.services.mautrix-discord.enable;
    pluralDisabled = !atlas.matrix.plural.enable && atlas.matrix.plural.allowedRooms == [];
    cutoffRemoved = atlas.matrix.discord.mediaRetentionBefore == {};
    dmRegistrationPreserved = lib.any (filename: lib.hasInfix "discord-registration" filename) atlas.services.matrix-synapse.settings.app_service_config_files;
    pluralRegistrationRemoved = lib.all (filename: !(lib.hasInfix "pluralmatrix" filename)) atlas.services.matrix-synapse.settings.app_service_config_files;
    sharedCredentialsPreserved = lib.all (name: builtins.hasAttr name atlas.age.secrets) sharedCredentials;
    pluralCredentialRemoved = !(atlas.age.secrets ? pluralmatrix-credentials);
    pluralUnitsRemoved = lib.all (name: !(builtins.hasAttr name atlas.systemd.services)) ["pluralmatrix" "pluralmatrix-registration"];
    pluralBridgeEnvironmentRemoved = !(atlas.systemd.services.mautrix-discord.environment ? PLURALMATRIX_ROOMS);
    relayAdminRemoved = !(builtins.hasAttr "@sec-hive-relay:bylisa.dev" atlas.services.mautrix-discord.settings.bridge.permissions);
    personalAdminPreserved = atlas.services.mautrix-discord.settings.bridge.permissions."@lisa:bylisa.dev" == "admin";
    backupPreserved = atlas.services.restic.backups ? matrix && atlas.systemd.services ? restic-backups-matrix && atlas.systemd.services ? matrix-restore-check;
    migrationVerificationDisabled = atlas.matrix.backup.historyVerificationDirectory == null;
    backupMountPreserved = lib.any (mount: mount.where == "/var/backup/matrix-coordinated") atlas.systemd.mounts;
    corePreserved = atlas.matrix.enable && atlas.services.matrix-synapse.enable && atlas.services.postgresql.enable;
    coreDatabasePreserved = builtins.elem "matrix-synapse" atlas.services.postgresql.ensureDatabases;
    dmBridgeDatabasePreserved = builtins.elem "mautrix-discord" atlas.services.postgresql.ensureDatabases;
    pluralDatabaseUnmanaged = !(builtins.elem "pluralmatrix" atlas.services.postgresql.ensureDatabases);
    volumePreserved = atlas.matrix.volume.enable && atlas.matrix.volume.device == "/dev/disk/by-id/scsi-0HC_Volume_107199635";
    mediaMountPreserved = lib.any (mount: mount.where == "/var/lib/matrix-synapse/media_store") atlas.systemd.mounts;
    pluralHostRemoved = !(atlas.services.nginx.virtualHosts ? "plural.bylisa.dev");
    nookEndpointsPreserved = lib.all (name: builtins.hasAttr name nook.users.users) ["matrix-media" "matrix-backup"] && nook.systemd.services ? matrix-backup-repository && nook.systemd.services ? matrix-media-directory;
    nookNfsPreserved = nook.services.nfs.server.enable;
  };
  failures = builtins.attrNames (lib.filterAttrs (_: passed: !passed) checks);
in {
  flake.checks.x86_64-linux.matrix-decommission = assert lib.assertMsg (failures == []) "SEC-Hive decommission assertions failed: ${lib.concatStringsSep ", " failures}";
    pkgs.runCommand "matrix-sec-hive-decommissioned" {} ''
      touch "$out"
    '';
}
