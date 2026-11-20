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
  # deploy-rs logs in with the same account as Lisa's workstations.
  deploy.hosts.nook.sshUser = config.network.nook.ssh.user;
  ci.targets = [
    {
      target = "nixosConfigurations.\"nook\".config.system.build.toplevel";
      inherit system;
      checks = ["nook" "deploy-schema-nook" "deploy-activate-nook"];
    }
  ];
}
