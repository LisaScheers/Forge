{
  overlays.postplan-selfhosted = final: _prev: {
    postplan-selfhosted = final.callPackage ../../../packages/postplan/postplan-selfhosted.pkg.nix {};
  };
  perSystem = {pkgs, ...}: {packages.postplan-selfhosted = pkgs.postplan-selfhosted;};
}
