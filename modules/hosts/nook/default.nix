{
  config,
  inputs,
  ...
}: let
  host = "nook";
  system = "x86_64-linux";
in {
  network.${host} = {
    lan = "192.168.111.2";
    tailscale = "100.106.233.104";
    ssh = {
      user = "lisa";
      identityFile = "~/.ssh/home-server.pub";
    };
  };
  flake.nixosConfigurations.${host} = inputs.nixpkgs.lib.nixosSystem {
    inherit system;
    modules = [config.nixos.base config.nixos.${host}];
  };
  nixos.${host} = {
    networking.hostName = host;
    imports = [config.nixos.nook-hardware config.nixos.home-manager];
    home-manager.users.lisa = config.home.lisa-nook;
  };
  deploy.hosts.${host} = {};
}
