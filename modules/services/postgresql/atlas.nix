{config, ...}: let
  features = config.nixos;
  # Not in the nightly dump (docs/sec-hive-matrix.md).
  unbacked = ["matrix-synapse" "mautrix-discord" "pluralmatrix"];
in {
  nixos.atlas = {
    config,
    lib,
    pkgs,
    ...
  }: {
    imports = [features.postgresql-restore-guard];

    # Pin the running major independently of system.stateVersion.
    services.postgresql = {
      package = pkgs.postgresql_18;
      dataDir = "/var/lib/postgresql/18";
    };
    forge.postgresqlRestore.expectedDatabases = lib.subtractLists unbacked config.services.postgresql.ensureDatabases;

    # Keep cluster roles and other databases while omitting Matrix backups.
    # UTC, like Nook's copy timer, so the copy always follows the dump.
    services.postgresqlBackup = {
      enable = true;
      backupAll = true;
      pgdumpAllOptions = lib.concatMapStringsSep " " (database: "--exclude-database=${database}") unbacked;
      compression = "zstd";
      startAt = "*-*-* 03:00:00 UTC";
    };

    # A root-owned marker also blocks updates after a reboot during maintenance.
    systemd.services.nix-auto-sync-update.unitConfig.ConditionPathExists = "!/var/lib/postgresql/.forge-maintenance";
  };
}
