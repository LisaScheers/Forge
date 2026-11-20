{
  config,
  inputs,
  ...
}: let
  system = "x86_64-linux";
in {
  flake.nixosConfigurations.nook = inputs.nixpkgs.lib.nixosSystem {
    inherit system;
    modules = [config.nixos.base config.nixos.nook];
  };
  nixos.nook = {
    networking.hostName = "nook";
    imports = [config.nixos.nook-hardware config.nixos.home-manager];
    home-manager.users.lisa = config.home.lisa-nook;
  };
  flake.checks.${system}.nook = config.flake.nixosConfigurations.nook.config.system.build.toplevel;
  deploy.hosts.nook.sshUser = "lisa";
  ci.targets = [
    {
      target = "nixosConfigurations.\"nook\".config.system.build.toplevel";
      inherit system;
      checks = ["nook" "deploy-schema-nook" "deploy-activate-nook"];
    }
  ];
}
