{
  config,
  inputs,
  ...
}: {
  flake.nixosConfigurations.nook = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [config.nixos.base config.nixos.nook];
  };
  nixos.nook = {
    networking.hostName = "nook";
    imports = [config.nixos.nook-hardware config.nixos.home-manager];
    home-manager.users.lisa = config.home.lisa-nook;
  };
  flake.checks.x86_64-linux.nook = config.flake.nixosConfigurations.nook.config.system.build.toplevel;
  ci.targets = [
    {
      target = "nixosConfigurations.\"nook\".config.system.build.toplevel";
      system = "x86_64-linux";
    }
  ];
}
