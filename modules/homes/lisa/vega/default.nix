{
  config,
  inputs,
  withSystem,
  ...
}: let
  system = "aarch64-darwin";
in {
  home.lisa-vega = {
    imports = [config.home.lisa];

    home.stateVersion = "26.11";

    xdg.enable = true;

    programs.home-manager.enable = true;
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
