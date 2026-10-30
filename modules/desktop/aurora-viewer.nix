{
  config,
  lib,
  ...
}: {
  overlays.aurora-viewer = final: _prev: {
    aurora-viewer = final.callPackage ../../packages/aurora-viewer/package.nix {};
  };
  perSystem = {pkgs, ...}:
    lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
      packages.aurora-viewer = pkgs.aurora-viewer;
    };

  home.lisa-vega.imports = [config.home.aurora-viewer];
  home.aurora-viewer = {pkgs, ...}: {
    home.packages = [pkgs.aurora-viewer];
  };
}
