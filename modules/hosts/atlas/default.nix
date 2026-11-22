{
  config,
  inputs,
  ...
}: let
  host = "atlas";
  system = "x86_64-linux";
in {
  network.${host} = {
    tailscale = "100.87.26.75";
    ssh = {
      user = "lisa";
      identityFile = "~/.ssh/lisa@atlas.pub";
    };
  };
  flake.nixosConfigurations.${host} = inputs.nixpkgs.lib.nixosSystem {
    inherit system;
    modules = [config.nixos.base config.nixos.${host}];
  };
  nixos.${host} = {
    networking.hostName = host;
    imports = [config.nixos.atlas-hardware];
  };
  deploy.hosts.${host} = {};
}
