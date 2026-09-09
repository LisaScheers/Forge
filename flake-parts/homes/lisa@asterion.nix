{
  config,
  inputs,
  ...
}: {
  forge.homes."lisa@asterion" = {
    system = "aarch64-linux";
    module = config.forge.modules.homeManager."lisa@asterion";
  };
  flake.checks.aarch64-linux."home-lisa@asterion" = config.flake.homeConfigurations."lisa@asterion".activationPackage;
  forge.modules.homeManager."lisa@asterion" = {
    imports = [
      config.forge.modules.homeManager.lisa-shell
      inputs.onepassword-shell-plugins.hmModules.default
      config.forge.modules.homeManager.catppuccin
      config.forge.modules.homeManager.t3-code
      inputs.agenix.homeManagerModules.default
      config.forge.modules.homeManager.xdg-extra
    ];
  };
}
