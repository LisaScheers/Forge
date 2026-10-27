{
  config,
  inputs,
  lib,
  ...
}: let
  atlas = config.flake.nixosConfigurations.atlas.config;
  nook = config.flake.nixosConfigurations.nook.config;
  pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
  backupCredentials = ["matrix-backup-password" "matrix-backup-ssh-key"];
  checks = {
    dmBridgePreserved = atlas.matrix.discord.enable && atlas.services.mautrix-discord.enable;
    pluralDisabled = !atlas.matrix.plural.enable && atlas.matrix.plural.allowedRooms == [];
    cutoffRemoved = atlas.matrix.discord.mediaRetentionBefore == {};
    dmRegistrationPreserved = lib.any (filename: lib.hasInfix "discord-registration" filename) atlas.services.matrix-synapse.settings.app_service_config_files;
    pluralRegistrationRemoved = lib.all (filename: !(lib.hasInfix "pluralmatrix" filename)) atlas.services.matrix-synapse.settings.app_service_config_files;
    dmCredentialPreserved = atlas.age.secrets ? discord-bridge-env;
    backupCredentialsRemoved = lib.all (name: !(builtins.hasAttr name atlas.age.secrets)) backupCredentials;
    pluralCredentialRemoved = !(atlas.age.secrets ? pluralmatrix-credentials);
    pluralUnitsRemoved = lib.all (name: !(builtins.hasAttr name atlas.systemd.services)) ["pluralmatrix" "pluralmatrix-registration"];
    pluralBridgeEnvironmentRemoved = !(atlas.systemd.services.mautrix-discord.environment ? PLURALMATRIX_ROOMS);
    relayAdminRemoved = !(builtins.hasAttr "@sec-hive-relay:bylisa.dev" atlas.services.mautrix-discord.settings.bridge.permissions);
    personalAdminPreserved = atlas.services.mautrix-discord.settings.bridge.permissions."@lisa:bylisa.dev" == "admin";
    backupDisabled = !atlas.matrix.backup.enable && !(atlas.services.restic.backups ? matrix) && !(atlas.systemd.services ? restic-backups-matrix) && !(atlas.systemd.services ? matrix-restore-check);
    migrationVerificationDisabled = atlas.matrix.backup.historyVerificationDirectory == null;
    backupMountRemoved = lib.all (mount: mount.where != "/var/backup/matrix-coordinated") atlas.systemd.mounts;
    backupLayoutRemoved = !(lib.hasInfix "/recovery" atlas.systemd.services.matrix-volume-layout.script);
    globalBackupPreserved = atlas.services.postgresqlBackup.enable && atlas.services.postgresqlBackup.backupAll;
    matrixDatabaseBackupsExcluded = lib.splitString " " atlas.services.postgresqlBackup.pgdumpAllOptions == ["--exclude-database=matrix-synapse" "--exclude-database=mautrix-discord" "--exclude-database=pluralmatrix"];
    corePreserved = atlas.matrix.enable && atlas.services.matrix-synapse.enable && atlas.services.postgresql.enable;
    coreDatabasePreserved = builtins.elem "matrix-synapse" atlas.services.postgresql.ensureDatabases;
    dmBridgeDatabasePreserved = builtins.elem "mautrix-discord" atlas.services.postgresql.ensureDatabases;
    pluralDatabaseUnmanaged = !(builtins.elem "pluralmatrix" atlas.services.postgresql.ensureDatabases);
    volumePreserved = atlas.matrix.volume.enable && atlas.matrix.volume.device == "/dev/disk/by-id/scsi-0HC_Volume_107199635";
    mediaMountPreserved = lib.any (mount: mount.where == "/var/lib/matrix-synapse/media_store") atlas.systemd.mounts;
    pluralHostRemoved = !(atlas.services.nginx.virtualHosts ? "plural.bylisa.dev");
    nookMediaEndpointRemoved = !(nook.users.users ? matrix-media) && !(nook.systemd.services ? matrix-media-directory);
    nookBackupRoleRemoved = !(nook.users.users ? matrix-backup) && !(nook.systemd.services ? matrix-backup-repository);
    nookNfsRemoved = !nook.services.nfs.server.enable;
  };
  failures = builtins.attrNames (lib.filterAttrs (_: passed: !passed) checks);
in {
  flake.checks.x86_64-linux.matrix-decommission = assert lib.assertMsg (failures == []) "SEC-Hive decommission assertions failed: ${lib.concatStringsSep ", " failures}";
    pkgs.runCommand "matrix-sec-hive-decommissioned" {} ''
      touch "$out"
    '';

  flake.checks.x86_64-linux.matrix-backup-exclusion =
    pkgs.runCommand "matrix-backup-exclusion" {
      nativeBuildInputs = [atlas.services.postgresql.package];
    } ''
      export PGDATA="$PWD/database" PGHOST="$PWD/socket" PGPORT=55441 PGUSER=fixture_admin
      mkdir "$PGHOST"
      initdb --no-locale --encoding=UTF8 -U "$PGUSER" >/dev/null
      pg_ctl -l "$PWD/postgres.log" -o "-c listen_addresses= -c unix_socket_directories=$PGHOST -p $PGPORT" -w start >/dev/null
      trap 'pg_ctl -m immediate -w stop >/dev/null' EXIT

      psql -X -v ON_ERROR_STOP=1 -d postgres -c 'CREATE ROLE fixture_role' >/dev/null
      for database in matrix-synapse mautrix-discord pluralmatrix authentik forgejo postplan runtime_only matrix-synapse-keep; do
        createdb "$database"
        psql -X -v ON_ERROR_STOP=1 -d "$database" -c 'CREATE TABLE backup_fixture (payload text)' >/dev/null
      done
      pg_dumpall ${atlas.services.postgresqlBackup.pgdumpAllOptions} > filtered.sql

      for database in matrix-synapse mautrix-discord pluralmatrix; do
        if grep -Fx -- '-- Database "'"$database"'" dump' filtered.sql; then
          echo 'Matrix database was included in the global backup' >&2
          exit 1
        fi
      done
      for database in authentik forgejo postplan runtime_only matrix-synapse-keep postgres template1; do
        grep -Fx -- '-- Database "'"$database"'" dump' filtered.sql >/dev/null
      done
      grep -Fx 'CREATE ROLE fixture_role;' filtered.sql >/dev/null
      touch "$out"
    '';
}
