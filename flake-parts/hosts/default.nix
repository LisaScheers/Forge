{
  config,
  inputs,
  ...
}: let
  # The previous builder supplied its nixpkgs-lib as the NixOS module `lib`,
  # which made that revision part of every system label. Preserve the label
  # without continuing to override the module system's own `lib` argument.
  legacyNixosVersion = inputs.flake-parts.inputs.nixpkgs-lib.lib.version;
  legacyNixosVersionSuffix = builtins.head (builtins.match "[0-9]+\\.[0-9]+(.*)" legacyNixosVersion);

  mkNixosHost = hostName: system: extraModules:
    inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      modules =
        [
          {
            forge.security.agenix.enable = true;
            forge.security.sops.enable = true;
            networking.hostName = hostName;
            nixpkgs.config.allowUnfree = true;
            nixpkgs.overlays = [config.flake.overlays.default];
            system.nixos.versionSuffix = legacyNixosVersionSuffix;
          }
          inputs.disko.nixosModules.disko
          config.flake.modules.nixos.networking
          config.flake.modules.nixos.security_agenix
          config.flake.modules.nixos.security_sops
          config.flake.modules.nixos.${hostName}
        ]
        ++ extraModules;
    };

  mkDarwinHost = hostName: system: extraModules:
    inputs.nix-darwin.lib.darwinSystem {
      inherit system;
      modules =
        [
          {
            forge.security.agenix.enable = true;
            forge.security.sops.enable = true;
            networking.hostName = hostName;
            nixpkgs.config.allowUnfree = true;
            nixpkgs.overlays = [config.flake.overlays.default];
          }
          inputs.nix-homebrew.darwinModules.nix-homebrew
          config.flake.modules.darwin.networking
          config.flake.modules.darwin.security_agenix
          config.flake.modules.darwin.security_sops
          config.flake.modules.darwin.${hostName}
        ]
        ++ extraModules;
    };
in {
  flake.nixosConfigurations = {
    nook = mkNixosHost "nook" "x86_64-linux" [
      inputs.home-manager.nixosModules.home-manager
      {
        home-manager = {
          backupFileExtension = "before-nix-home-manager";
          useGlobalPkgs = true;
          useUserPackages = true;
        };
      }
    ];

    atlas = mkNixosHost "atlas" "x86_64-linux" [
      config.flake.modules.nixos.services_auto-sync-update
      config.flake.modules.nixos.services_authentik
      config.flake.modules.nixos.services_matrix
      inputs.shop-empty-track.nixosModules.default
      inputs.sl-remote.nixosModules.default
    ];
  };

  flake.darwinConfigurations.vega = mkDarwinHost "vega" "aarch64-darwin" [
    inputs.home-manager.darwinModules.home-manager
    inputs.lix-module.darwinModules.default
    {
      home-manager = {
        backupFileExtension = "before-nix-home-manager";
        useGlobalPkgs = true;
        useUserPackages = true;
      };
    }
  ];

  flake.checks = {
    aarch64-darwin.vega = config.flake.darwinConfigurations.vega.system;
    x86_64-linux = {
      nook = config.flake.nixosConfigurations.nook.config.system.build.toplevel;
      atlas = config.flake.nixosConfigurations.atlas.config.system.build.toplevel;
    };
  };

  flake-file.inputs.disko.url = "github:nix-community/disko";
}
