{
  config,
  inputs,
  withSystem,
  ...
}: let
  system = "aarch64-darwin";
in {
  home.lisa-vega = {
    imports = [config.home.lisa config.home.workstation];
    home.stateVersion = "26.11";
    manual.manpages.enable = false;
  };
  flake.homeConfigurations."lisa@vega" = withSystem system ({pkgs, ...}:
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [config.home.lisa-vega];
    });
  flake.checks.${system}."home-lisa@vega" =
    config.flake.homeConfigurations."lisa@vega".activationPackage;
  ci.targets = [
    {
      target = "homeConfigurations.\"lisa@vega\".activationPackage";
      inherit system;
      checks = ["home-lisa@vega"];
    }
  ];
}
