{
  # Asterion runs Zed's upstream Linux build, with Ghostty as its terminal.
  home.lisa-asterion = {
    lib,
    pkgs,
    ...
  }: let
    zed = pkgs.callPackage ../../../packages/asterion-zed-bin/package.nix {};
  in {
    programs.zed-editor = {
      package = zed;
      userSettings = {
        auto_update = false;
        terminal.env.TERM = lib.mkForce "xterm-ghostty";
      };
    };
  };
}
