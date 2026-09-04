{config, ...}: {
  flake.modules.homeManager."lisa@nook" = {
    imports = [
      config.flake.modules.homeManager.lisa
      (./. + "/_lisa@nook")
    ];
  };
}
