{
  overlays.discord-migration = final: _prev: {
    discord-migration = final.callPackage ../../packages/discord-migration/discord-migration.pkg.nix {};
  };
  perSystem = {pkgs, ...}: {
    packages.discord-migration = pkgs.discord-migration;
    checks.discord-migration = pkgs.discord-migration;
  };
}
