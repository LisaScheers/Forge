{
  config,
  inputs,
  ...
}: let
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
      inputs.home-manager.darwinModules.home-manager
      inputs.lix-module.darwinModules.default
    ];
    home-manager = {
      backupFileExtension = "before-nix-home-manager";
      useGlobalPkgs = true;
      useUserPackages = true;
    };
    users.users.lisa.home = "/Users/lisa";
    home-manager.users.lisa.imports = [lisaHome];
  };

  flake-file.inputs = {
    nix-darwin = {
      url = "https://flakehub.com/f/nix-darwin/nix-darwin/0.1.*";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    lix = {
      url = "https://git.lix.systems/lix-project/lix/archive/main.tar.gz";
      flake = false;
    };
    lix-module = {
      url = "https://git.lix.systems/lix-project/nixos-module/archive/main.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.lix.follows = "lix";
    };
  };
}
