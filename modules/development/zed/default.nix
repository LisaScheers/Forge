{ inputs, ... }: {
  home."lisa" = { pkgs, ... }: {
    programs.zed-editor.enable = pkgs.stdenv.hostPlatform.isDarwin;
    programs.zed-editor.package = null;
  };
  overlays.zed = final: _prev: {
    # Use Zed's own Nixpkgs pin and build unchanged so zed.cachix.org has the result.
    zed-editor = inputs.zed.packages.${final.stdenv.hostPlatform.system}.default;
  };
  flake-file.inputs.zed.url = "github:zed-industries/zed";
  perSystem = { pkgs, ... }: { packages.zed-editor = pkgs.zed-editor; };
}
