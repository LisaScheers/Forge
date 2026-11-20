{
  config,
  inputs,
  ...
}: let
  system = "aarch64-darwin";
in {
  flake-file.inputs.nix-darwin = {
    url = "https://flakehub.com/f/nix-darwin/nix-darwin/0.1.*";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  flake.darwinConfigurations.vega = inputs.nix-darwin.lib.darwinSystem {
    inherit system;
    modules = [config.darwin.base config.darwin.vega];
  };
  darwin.vega = {
    networking.hostName = "vega";
    imports = [config.darwin.home-manager];
    home-manager.users.lisa = config.home.lisa-vega;
    users.users.lisa.home = "/Users/lisa";
  };
  flake.checks.${system}.vega = config.flake.darwinConfigurations.vega.system;
  ci.targets = [
    {
      target = "darwinConfigurations.\"vega\".system";
      inherit system;
      checks = ["vega" "deploy-schema-vega" "deploy-activate-vega"];
    }
  ];
}
