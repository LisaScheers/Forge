{
  config,
  inputs,
  withSystem,
  ...
}: let
  system = "aarch64-linux";
in {
  home.lisa-asterion = {
    imports = [config.home.lisa];

    home.stateVersion = "26.11";
    xdg.enable = true;
    programs.home-manager.enable = true;
  };
  flake.homeConfigurations."lisa@asterion" = withSystem system ({pkgs, ...}:
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [config.home.lisa-asterion];
    });
  flake.checks.${system}."home-lisa@asterion" =
    config.flake.homeConfigurations."lisa@asterion".activationPackage;
  ci.targets = [
    {
      target = "homeConfigurations.\"lisa@asterion\".activationPackage";
      inherit system;
      checks = ["home-lisa@asterion"];
    }
  ];
}
