{
  home.workstation = {
    config,
    lib,
    pkgs,
    ...
  }: let
    inherit (pkgs.stdenv.hostPlatform) isDarwin;
  in {
    programs.ghostty = {
      enable = true;
      # Darwin installs Ghostty system-wide with ghostty-bin because the source
      # package is not supported there; Asterion builds it from source.
      package =
        if isDarwin
        then null
        else pkgs.ghostty;
      settings = {
        command = "direct:${lib.getExe pkgs.nushell}";
        env = ["XDG_CONFIG_HOME=${config.xdg.configHome}"];
        shell-integration-features = "sudo,ssh-env,ssh-terminfo,path";

        font-family = "ComicCodeLigatures Nerd Font";
        font-family-bold = "ComicCodeLigatures Nerd Font";
        font-style-bold = "Bold";
        font-family-italic = "ComicCodeLigatures Nerd Font";
        font-style-italic = "Italic";
        font-family-bold-italic = "ComicCodeLigatures Nerd Font";
        font-style-bold-italic = "Bold Italic";

        background-opacity = 0.9;
      };
    };
    home.packages = lib.optional isDarwin pkgs.ghostty-bin.terminfo;
  };
}
