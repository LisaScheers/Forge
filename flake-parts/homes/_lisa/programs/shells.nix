{
  config,
  pkgs,
  lib,
  ...
}: let
  zed = lib.getExe pkgs.zed-editor;
in {
  home.sessionVariables = lib.mkIf config.programs.zed-editor.enable {
    NIXPKGS_ALLOW_UNFREE = "1";
    EDITOR = "${zed} --wait";
    VISUAL = "${zed} --wait";
  };
}
