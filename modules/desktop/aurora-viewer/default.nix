{
  config,
  lib,
  ...
}: {
  overlays.aurora-viewer = final: _prev: {
    aurora-viewer = final.callPackage ../../../packages/aurora-viewer/package.nix {};
  };
  perSystem = {pkgs, ...}:
    lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
      packages.aurora-viewer = pkgs.aurora-viewer;
    };

  # No binary cache has it: Vega compiles it (with its tests) whenever the
  # source or its Nixpkgs inputs change.
  home.aurora-viewer = {pkgs, ...}: {
    home.packages = [pkgs.aurora-viewer];
  };
  home.lisa-vega.imports = [config.home.aurora-viewer];

  # Exported from Aurora's settings UI; the viewer may rewrite these files.
  home.lisa-vega.forge.mutablePreferences = {
    "Library/Application Support/org.Aurora.AuroraViewer/settings.json".settings = lib.importJSON ./settings.json;
    "Library/Application Support/org.Aurora.AuroraViewer/demo/settings.json".settings = lib.importJSON ./demo-settings.json;
  };
}
