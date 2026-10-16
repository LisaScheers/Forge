{inputs, ...}: {
  # Keep the deployed application version fixed through the PostgreSQL cutover.
  flake-file.inputs.nixpkgs-atlas-apps.url = "github:NixOS/nixpkgs/67b5cf9be1c8d2170270509db4ed12e904a768b0";

  nixos.atlas = {lib, pkgs, ...}: {
    services.forgejo.package = inputs.nixpkgs-atlas-apps.legacyPackages.x86_64-linux.forgejo-lts;
    # Pin the running major independently of system.stateVersion.
    services.postgresql = {
      package = pkgs.postgresql_18;
      dataDir = "/var/lib/postgresql/18";
    };

    # Never let the NixOS initializer replace a missing or incomplete migration
    # with an empty cluster. Create this marker only after pg_upgrade succeeds.
    systemd.services.postgresql.preStart = lib.mkBefore ''
      test "$(cat /var/lib/postgresql/18/PG_VERSION)" = 18
      test -f /var/lib/postgresql/18/.forge-upgrade-complete
    '';

    # pg_dumpall includes every database and cluster roles/permissions.
    services.postgresqlBackup = {
      enable = true;
      backupAll = true;
      compression = "zstd";
      startAt = "*-*-* 03:00:00";
    };

    # A root-owned marker also blocks updates after a reboot during maintenance.
    systemd.services.nix-auto-sync-update.unitConfig.ConditionPathExists = "!/var/lib/postgresql/.forge-maintenance";
  };
}
