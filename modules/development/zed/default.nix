{ inputs, ... }: {
  home."lisa" = { pkgs, ... }: {
    programs.zed-editor.enable = pkgs.stdenv.hostPlatform.isDarwin;
    programs.zed-editor.package = null;
  };
  overlays.zed = final: _prev: {
    zed-editor = inputs.zed.packages.${final.stdenv.hostPlatform.system}.default.override {
      # Zed's older fork has no tests/common.rs for Nixpkgs' integration-test patch.
      cargo-bundle = final.cargo-bundle.overrideAttrs {
        patches = [ ];
      };
    };
  };
  flake-file.inputs.zed = {
    url = "github:zed-industries/zed";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  perSystem = { pkgs, ... }: { packages.zed-editor = pkgs.zed-editor; };
}
