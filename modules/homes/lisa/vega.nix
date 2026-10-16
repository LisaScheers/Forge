{
  config,
  inputs,
  withSystem,
  ...
}: {
  home.lisa-vega = {
    imports = [config.home.lisa];

    home.username = "lisa";
    home.homeDirectory = "/Users/lisa";

    xdg.enable = true;

    programs.home-manager.enable = true;
    manual.manpages.enable = false;
  };
  flake.homeConfigurations."lisa@vega" = withSystem "aarch64-darwin" ({pkgs, ...}:
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [config.home.lisa-vega];
    });
  flake.checks.aarch64-darwin."home-lisa@vega" =
    config.flake.homeConfigurations."lisa@vega".config.home.path;
  ci.targets = [
    {
      target = "homeConfigurations.\"lisa@vega\".activationPackage";
      system = "aarch64-darwin";
    }
  ];
}
