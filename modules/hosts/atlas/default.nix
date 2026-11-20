{
  config,
  inputs,
  ...
}: let
  system = "x86_64-linux";
in {
  flake.nixosConfigurations.atlas = inputs.nixpkgs.lib.nixosSystem {
    inherit system;
    modules = [config.nixos.base config.nixos.atlas];
  };
  nixos.atlas = {
    networking.hostName = "atlas";
    imports = [config.nixos.atlas-hardware];
  };
  flake.checks.${system}.atlas = config.flake.nixosConfigurations.atlas.config.system.build.toplevel;
  ci.targets = [
    {
      target = "nixosConfigurations.\"atlas\".config.system.build.toplevel";
      inherit system;
      checks = ["atlas" "deploy-schema-atlas" "deploy-activate-atlas"];
    }
  ];
}
