{
  config,
  inputs,
  ...
}: {
  flake.nixosConfigurations.atlas = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [config.nixos.base config.nixos.atlas];
  };
  nixos.atlas = {
    networking.hostName = "atlas";
    imports = [config.nixos.atlas-hardware];
  };
  flake.checks.x86_64-linux.atlas = config.flake.nixosConfigurations.atlas.config.system.build.toplevel;
  ci.targets = [
    {
      target = "nixosConfigurations.\"atlas\".config.system.build.toplevel";
      system = "x86_64-linux";
    }
  ];
}
