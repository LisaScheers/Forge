{
  config,
  inputs,
  ...
}: let
  host = "vega";
  system = "aarch64-darwin";
in {
  flake-file.inputs.nix-darwin = {
    url = "https://flakehub.com/f/nix-darwin/nix-darwin/0.1.*";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  flake.darwinConfigurations.${host} = inputs.nix-darwin.lib.darwinSystem {
    inherit system;
    modules = [config.darwin.base config.darwin.${host}];
  };
  darwin.${host} = {
    networking.hostName = host;
    imports = [config.darwin.home-manager];
    home-manager.users.lisa = config.home.lisa-vega;
    users.users.lisa.home = "/Users/lisa";
  };
  deploy.hosts.${host} = {
    hostname = "localhost";
    sshUser = "lisa";
    interactiveSudo = true;
  };
}
