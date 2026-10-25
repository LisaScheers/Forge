{
  config,
  inputs,
  withSystem,
  ...
}: {
  home.lisa-asterion = {
    imports = [config.home.lisa];

    home = {
      username = "lisa";
      homeDirectory = "/home/lisa";
      stateVersion = "26.11";
    };
    xdg.enable = true;
    programs.home-manager.enable = true;
  };
  flake.homeConfigurations."lisa@asterion" = withSystem "aarch64-linux" ({pkgs, ...}:
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [config.home.lisa-asterion];
    });
  flake.checks.aarch64-linux."home-lisa@asterion" =
    config.flake.homeConfigurations."lisa@asterion".activationPackage;
  ci.targets = [
    {
      target = "homeConfigurations.\"lisa@asterion\".activationPackage";
      system = "aarch64-linux";
    }
  ];
}
