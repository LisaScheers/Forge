{
  config,
  inputs,
  lib,
  ...
}: {
  flake = {
    nixosConfigurations = lib.mapAttrs (
      name: host:
        inputs.nixpkgs.lib.nixosSystem {
          inherit (host) system;
          modules = [
            config.forge.modules.nixos.base
            {networking.hostName = name;}
            host.module
          ];
        }
    ) (lib.filterAttrs (_: host: host.class == "nixos") config.forge.hosts);

    darwinConfigurations = lib.mapAttrs (
      name: host:
        inputs.nix-darwin.lib.darwinSystem {
          inherit (host) system;
          modules = [
            config.forge.modules.darwin.base
            {networking.hostName = name;}
            host.module
          ];
        }
    ) (lib.filterAttrs (_: host: host.class == "darwin") config.forge.hosts);

    homeConfigurations =
      lib.mapAttrs (
        _: home:
          inputs.home-manager.lib.homeManagerConfiguration {
            pkgs = import inputs.nixpkgs {
              inherit (home) system;
              overlays = [config.flake.overlays.default];
              config.allowUnfree = true;
            };
            modules = [home.module];
          }
      )
      config.forge.homes;
  };
}
