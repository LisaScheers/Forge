{
  imports = [
    ./desktop.nix
    ../_lisa/programs/bash.nix
    ../_lisa/programs/zsh.nix
    ../_lisa/programs/git.nix
    ../_lisa/programs/direnv.nix
  ];

  home = {
    username = "lisa";
    homeDirectory = "/home/lisa";
    stateVersion = "26.05";
  };
  xdg.enable = true;
  programs.home-manager.enable = true;
}
