{
  home.lisa = {config, ...}: let
    homeDirectory = config.home.homeDirectory;
  in {
    home.sessionVariables = {
      XDG_DESKTOP_DIR = "${homeDirectory}/Desktop";
      XDG_DOCUMENTS_DIR = "${homeDirectory}/Documents";
      XDG_DOWNLOAD_DIR = "${homeDirectory}/Downloads";
      XDG_PICTURES_DIR = "${homeDirectory}/Pictures";
      XDG_MUSIC_DIR = "${homeDirectory}/Music";
      XDG_VIDEOS_DIR = "${homeDirectory}/Videos";
      XDG_PROJECTS_DIR = "${homeDirectory}/Projects";
    };
    xdg.configFile."nix/nix.conf".text = ''
      experimental-features = nix-command flakes
    '';
  };
}
