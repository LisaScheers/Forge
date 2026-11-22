{
  config,
  inputs,
  withSystem,
  ...
}: let
  system = "x86_64-linux";
in {
  home.lisa-nook = {
    imports = [config.home.lisa];

    home.stateVersion = "26.11";
  };
  flake.homeConfigurations."lisa@nook" = withSystem system ({pkgs, ...}:
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [config.home.lisa-nook];
    });
  flake.checks.${system}."home-lisa@nook" =
    config.flake.homeConfigurations."lisa@nook".activationPackage;
  ci.targets = [
    {
      target = "homeConfigurations.\"lisa@nook\".activationPackage";
      inherit system;
      checks = ["home-lisa@nook"];
    }
  ];
}
