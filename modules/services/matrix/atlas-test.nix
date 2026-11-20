{
  config,
  lib,
  withSystem,
  ...
}: let
  atlas = config.flake.nixosConfigurations.atlas.config;
  # What Atlas must keep after SEC-Hive: the DM bridge, the core server and its
  # storage, and global backups that leave the Matrix databases out by choice.
  checks = {
    dmBridgeEnabled = atlas.matrix.discord.enable && atlas.services.mautrix-discord.enable;
    dmRegistrationLoaded = lib.any (filename: lib.hasInfix "discord-registration" filename) atlas.services.matrix-synapse.settings.app_service_config_files;
    dmCredentialDeclared = atlas.age.secrets ? discord-bridge-env;
    personalAdmin = atlas.services.mautrix-discord.settings.bridge.permissions."@lisa:bylisa.dev" == "admin";
    noRelayAdmin = !(builtins.hasAttr "@sec-hive-relay:bylisa.dev" atlas.services.mautrix-discord.settings.bridge.permissions);
    databasesManaged = lib.all (name: builtins.elem name atlas.services.postgresql.ensureDatabases) ["matrix-synapse" "mautrix-discord"];
    # Media lives on the dedicated volume, addressed by a stable device identity.
    mediaOnVolume = atlas.matrix.volume.enable && lib.any (mount: mount.where == "/var/lib/matrix-synapse/media_store" && mount.what == "${atlas.matrix.volume.mountPoint}/media_store") atlas.systemd.mounts;
    volumeHasStableDevice = lib.hasPrefix "/dev/disk/by-id/" atlas.matrix.volume.device && atlas.fileSystems.${atlas.matrix.volume.mountPoint}.device == atlas.matrix.volume.device;
    globalBackupEnabled = atlas.services.postgresqlBackup.enable && atlas.services.postgresqlBackup.backupAll;
    matrixDatabasesExcluded = lib.splitString " " atlas.services.postgresqlBackup.pgdumpAllOptions == ["--exclude-database=matrix-synapse" "--exclude-database=mautrix-discord" "--exclude-database=pluralmatrix"];
  };
  failures = builtins.attrNames (lib.filterAttrs (_: passed: !passed) checks);
in {
  flake.checks.x86_64-linux = withSystem "x86_64-linux" ({pkgs, ...}: {
    matrix-atlas = assert lib.assertMsg (failures == []) "Atlas Matrix invariants failed: ${lib.concatStringsSep ", " failures}";
      pkgs.runCommand "matrix-atlas-invariants" {} ''
        touch "$out"
      '';

    matrix-backup-exclusion =
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
  });
}
