{config, ...}: let
  lisaHome = config.forge.modules.homeManager."lisa@vega";
in {
  forge.hosts.vega = {
    class = "darwin";
    system = "aarch64-darwin";
    module = config.forge.modules.darwin.vega;
  };
  flake.checks.aarch64-darwin.vega = config.flake.darwinConfigurations.vega.system;
  forge.modules.darwin.vega = {
    imports = [
    ];
    home-manager = {
      backupFileExtension = "before-nix-home-manager";
      useGlobalPkgs = true;
      useUserPackages = true;
    };
    users.users.lisa.home = "/Users/lisa";
    home-manager.users.lisa.imports = [lisaHome];
  };
}
