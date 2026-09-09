{
  imports = [
    ./desktop.nix
    ../lisa/programs/bash.nix
    ../lisa/programs/zsh.nix
    ../lisa/programs/git.nix
    ../lisa/programs/direnv.nix
  ];

  home = {
    username = "lisa";
    homeDirectory = "/home/lisa";
    stateVersion = "26.05";
  };
  xdg.enable = true;
  programs.home-manager.enable = true;
}
