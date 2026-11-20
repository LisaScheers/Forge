{
  inputs,
  lib,
  ...
}: {
  home."lisa" = {pkgs, ...}: {
    programs.zed-editor.enable = pkgs.stdenv.hostPlatform.isDarwin;
    # Vega installs Zed Nightly system-wide; Asterion selects its own build.
    programs.zed-editor.package = lib.mkDefault null;
  };
  overlays.zed = final: _prev: {
    # Use Zed's own Nixpkgs pin and build unchanged so zed.cachix.org has the result.
    zed-editor = inputs.zed.packages.${final.stdenv.hostPlatform.system}.default;
  };
  flake-file.inputs.zed.url = "github:zed-industries/zed";
  perSystem = {pkgs, ...}: {packages.zed-editor = pkgs.zed-editor;};
}
