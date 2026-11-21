{
  # Zed is the editor wherever home.workstation enables it.
  home.workstation = {
    config,
    pkgs,
    lib,
    ...
  }: let
    # Vega's home leaves the package to the system install of the same build.
    zed = lib.getExe (
      if config.programs.zed-editor.package != null
      then config.programs.zed-editor.package
      else pkgs.zed-editor
    );
  in {
    home.sessionVariables = lib.mkIf config.programs.zed-editor.enable {
      NIXPKGS_ALLOW_UNFREE = "1";
      EDITOR = "${zed} --wait";
      VISUAL = "${zed} --wait";
    };
  };
}
