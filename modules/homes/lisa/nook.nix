{
  config,
  inputs,
  withSystem,
  ...
}: {
  home.lisa-nook = {
    imports = [config.home.lisa];

    home.homeDirectory = "/home/lisa";
    home.stateVersion = "26.11";
  };
  flake.homeConfigurations."lisa@nook" = withSystem "x86_64-linux" ({pkgs, ...}:
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [config.home.lisa-nook];
    });
  flake.checks.x86_64-linux."home-lisa@nook" =
    config.flake.homeConfigurations."lisa@nook".config.home.path;
  ci.targets = [
    {
      target = "homeConfigurations.\"lisa@nook\".activationPackage";
      system = "x86_64-linux";
    }
  ];
}
