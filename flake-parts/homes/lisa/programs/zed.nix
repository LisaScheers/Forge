{inputs, ...}: {
  forge.modules.homeManager."lisa" = {pkgs, ...}: {
    programs.zed-editor.enable = pkgs.stdenv.hostPlatform.isDarwin;
  };
  forge.overlays.zed = final: _prev: {
    zed-editor = inputs.zed.packages.${final.stdenv.hostPlatform.system}.default.override {
      # Zed pins cargo-about to 0.8.2, which does not have the inherited `cli` feature.
      cargo-about = final.cargo-about.overrideAttrs (_old: {
        cargoBuildFeatures = [];
        cargoCheckFeatures = [];
      });
    };
  };
  flake-file.inputs.zed = {
    url = "github:zed-industries/zed";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  perSystem = {pkgs, ...}: {packages.zed-editor = pkgs.zed-editor;};
}
