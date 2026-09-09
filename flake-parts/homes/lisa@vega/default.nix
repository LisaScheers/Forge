{...}: {
  forge.modules.homeManager."lisa@vega" = {
    home.username = "lisa";
    home.homeDirectory = "/Users/lisa";

    xdg.enable = true;

    programs.home-manager.enable = true;
    manual.manpages.enable = false;
  };
}
