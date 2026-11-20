{
  config,
  inputs,
  ...
}: let
  system = "aarch64-linux";
in {
  flake.nixosConfigurations.asterion = inputs.nixpkgs.lib.nixosSystem {
    inherit system;
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
  flake.checks.${system}.asterion = config.flake.nixosConfigurations.asterion.config.system.build.toplevel;
  ci.targets = [
    {
      target = "nixosConfigurations.\"asterion\".config.system.build.toplevel";
      inherit system;
      checks = ["asterion" "deploy-schema-asterion" "deploy-activate-asterion"];
    }
  ];
}
