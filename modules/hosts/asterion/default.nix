{
  config,
  inputs,
  ...
}: let
  host = "asterion";
  system = "aarch64-linux";
in {
  flake.nixosConfigurations.${host} = inputs.nixpkgs.lib.nixosSystem {
    inherit system;
    modules = [config.nixos.base config.nixos.${host}];
  };
  nixos.${host} = {
    networking.hostName = host;
    imports = [
      config.nixos.apple-silicon
      config.nixos.asterion-hardware
      config.nixos.asterion-gpu
      config.nixos.asterion-gpu-boot
      config.nixos.asterion-audio
      config.nixos.home-manager
    ];
    home-manager.users.lisa = config.home.lisa-asterion;
  };
  deploy.hosts.${host}.sshUser = "root";
}
