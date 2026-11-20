{
  overlays.postplan-selfhosted = final: _prev: {
    postplan-selfhosted = final.callPackage ../../../packages/postplan/package.nix {};
  };
  perSystem = {pkgs, ...}: {packages.postplan-selfhosted = pkgs.postplan-selfhosted;};
}
