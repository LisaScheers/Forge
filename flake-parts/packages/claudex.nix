{inputs, ...}: {
  forge.overlays.claudex = final: _prev: {
    claudex = final.callPackage ./claudex.pkg.nix {};
  };
  perSystem = {pkgs, ...}: {packages.claudex = pkgs.claudex;};
}
