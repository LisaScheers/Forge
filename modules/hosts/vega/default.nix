{
  config,
  inputs,
  ...
}: {
  flake-file.inputs.nix-darwin = {
    url = "https://flakehub.com/f/nix-darwin/nix-darwin/0.1.*";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  flake.darwinConfigurations.vega = inputs.nix-darwin.lib.darwinSystem {
    system = "aarch64-darwin";
    modules = [config.darwin.base config.darwin.vega];
  };
  darwin.vega = {
    networking.hostName = "vega";
    imports = [config.darwin.home-manager];
    home-manager.users.lisa = config.home.lisa-vega;
    users.users.lisa.home = "/Users/lisa";
  };
  flake.checks.aarch64-darwin.vega = config.flake.darwinConfigurations.vega.system;
  ci.targets = [
    {
      target = "darwinConfigurations.\"vega\".system";
      system = "aarch64-darwin";
    }
  ];
}
