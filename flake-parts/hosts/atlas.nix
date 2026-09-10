{
  config,
  inputs,
  ...
}: {
  forge.hosts.atlas = {
    class = "nixos";
    system = "x86_64-linux";
    module = config.forge.modules.nixos.atlas;
  };
  flake.checks.x86_64-linux.atlas = config.flake.nixosConfigurations.atlas.config.system.build.toplevel;
  forge.modules.nixos.atlas = {
    imports = [
      config.forge.modules.nixos.services_auto-sync-update
      config.forge.modules.nixos.services_authentik
      config.forge.modules.nixos.services_matrix
      inputs.shop-empty-track.nixosModules.default
      inputs.sl-remote.nixosModules.default
    ];
  };
}
