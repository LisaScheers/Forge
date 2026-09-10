{config, ...}: {
  forge.homes."lisa@nook" = {
    system = "x86_64-linux";
    module = config.forge.modules.homeManager."lisa@nook";
  };
  flake.checks.x86_64-linux."home-lisa@nook" = config.flake.homeConfigurations."lisa@nook".config.home.path;
  forge.modules.homeManager."lisa@nook" = {
    imports = [
      config.forge.modules.homeManager.lisa
    ];
  };
}
