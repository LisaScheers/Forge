{
  overlays.forgejo-api = final: _prev: {
    forgejo-api = final.callPackage ../../packages/forgejo-api/forgejo-api.pkg.nix {};
  };
  perSystem = {pkgs, ...}: {
    packages.forgejo-api = pkgs.forgejo-api;
    checks.forgejo-api = pkgs.forgejo-api;
  };
}
