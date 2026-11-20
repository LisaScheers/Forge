{
  # Guards a PostgreSQL cluster that may only start after a verified upgrade or
  # restore, and installs the restore command for it with the host's own
  # server package, data directory and expected databases.
  nixos.postgresql-restore-guard = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.postgresql;
  in {
    options.forge.postgresqlRestore.expectedDatabases = lib.mkOption {
      type = lib.types.listOf (lib.types.strMatching "[A-Za-z0-9_-]+");
      default = [];
      description = "Databases a restore must bring back before the cluster is marked ready.";
    };

    config = {
      environment.systemPackages = [
        (pkgs.callPackage ../../../packages/forge-postgresql-restore/package.nix {
          # With the service's extensions, so the dump's CREATE EXTENSION works.
          postgresql = cfg.finalPackage;
          inherit (cfg) dataDir;
          inherit (config.forge.postgresqlRestore) expectedDatabases;
        })
      ];
      # Never let the NixOS initializer replace a missing or incomplete
      # migration with an empty cluster; the marker comes from pg_upgrade or
      # forge-postgresql-restore.
      systemd.services.postgresql.preStart = lib.mkBefore ''
        test "$(cat ${lib.escapeShellArg "${cfg.dataDir}/PG_VERSION"})" = ${lib.versions.major cfg.package.version}
        test -f ${lib.escapeShellArg "${cfg.dataDir}/.forge-upgrade-complete"}
      '';
    };
  };
}
