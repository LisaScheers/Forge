{config, ...}: {
  forge.homes."lisa@vega" = {
    system = "aarch64-darwin";
    module = config.forge.modules.homeManager."lisa@vega";
  };
  flake.checks.aarch64-darwin."home-lisa@vega" = config.flake.homeConfigurations."lisa@vega".config.home.path;
  forge.modules.homeManager."lisa@vega" = {
    imports = [
      config.forge.modules.homeManager.lisa
      config.forge.modules.homeManager.spotaui
      config.forge.modules.homeManager.chrome-tab
    ];
    forge.chrome-tab.enable = true;
  };
}
