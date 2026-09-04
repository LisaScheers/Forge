{config, ...}: {
  flake.modules.homeManager."lisa@vega" = {
    imports = [
      config.flake.modules.homeManager.lisa
      (./. + "/_lisa@vega")
      ./_lisa/darwin.nix
    ];
  };
}
