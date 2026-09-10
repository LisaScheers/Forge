{
  forge.modules.homeManager."lisa@asterion" = {
    home = {
      username = "lisa";
      homeDirectory = "/home/lisa";
      stateVersion = "26.05";
    };
    xdg.enable = true;
    programs.home-manager.enable = true;
  };
}
