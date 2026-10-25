{
  config,
  inputs,
  ...
}: {
  flake.nixosConfigurations.asterion = inputs.nixpkgs.lib.nixosSystem {
    system = "aarch64-linux";
    modules = [config.nixos.base config.nixos.asterion];
  };
  nixos.asterion = {
    networking.hostName = "asterion";
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
  ci.targets = [
    {
      target = "nixosConfigurations.\"asterion\".config.system.build.toplevel";
      system = "aarch64-linux";
    }
  ];
}
