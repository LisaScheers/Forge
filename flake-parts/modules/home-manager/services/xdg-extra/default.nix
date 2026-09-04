{...}: {
  flake.modules.homeManager.xdg-extra = {
    config,
    lib,
    ...
  }: {
    options = {
      xdg-extra.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable the xdg-extra module which sets up XDG directories and other related configuration.";
      };
    };
    config = lib.mkIf config.xdg-extra.enable (
      let
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

        #todo: Move

        xdg.configFile."nix/nix.conf".text = ''
          experimental-features = nix-command flakes
          !include /run/secrets/nix/user-github-access-token.conf
        '';
      }
    );
  };
}
