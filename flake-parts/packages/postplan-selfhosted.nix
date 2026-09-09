{inputs, ...}: {
  forge.overlays.postplan-selfhosted = final: _prev: {
    postplan-selfhosted = final.callPackage ./postplan-selfhosted.pkg.nix {};
  };
  perSystem = {pkgs, ...}: {packages.postplan-selfhosted = pkgs.postplan-selfhosted;};
}
