# --- flake-parts/hosts/default.nix
{
  lib,
  inputs,
  withSystem,
  config,
  ...
}: let
  mkHost = args: hostName: {
    extraSpecialArgs ? {},
    extraModules ? [],
    extraOverlays ? [],
    withHomeManager ? false,
    ...
  }: let
    baseSpecialArgs =
      {
        inherit (args) system;
        inherit inputs hostName;
      }
      // extraSpecialArgs;
  in
    inputs.nixpkgs.lib.nixosSystem {
      inherit (args) system;
      specialArgs =
        baseSpecialArgs
        // {
          inherit lib hostName;
          host.hostName = hostName;
          flakeRevision = inputs.self.rev or inputs.self.dirtyRev or null;
        };
      modules =
        [
          {
            forge.security.agenix.enable = true;
            forge.security.sops.enable = true;
            nixpkgs.overlays = [config.flake.overlays.default] ++ extraOverlays;
            nixpkgs.config.allowUnfree = true;
            networking.hostName = hostName;
          }
          ./_nixos-networking.nix
          inputs.disko.nixosModules.disko
          config.flake.nixosModules.security_sops
          config.flake.nixosModules.security_agenix
          ./${hostName}
        ]
        ++ extraModules
        # NOTE You can also load all of your defined modules in the
        # following manner
        #
        # ++ (lib.attrValues config.flake.nixosModules)
        ++ (
          if (withHomeManager && (lib.hasAttr "home-manager" inputs))
          then [
            inputs.home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = baseSpecialArgs;

                # NOTE You can also load all of your defined modules in the
                # following manner
                #
                sharedModules = lib.attrValues config.flake.homeModules;
              };
            }
          ]
          else []
        );
    };
  mkDarwinHost = args: hostName: {
    extraSpecialArgs ? {},
    extraModules ? [],
    extraOverlays ? [],
    withHomeManager ? false,
    ...
  }: let
    baseSpecialArgs =
      {
        inherit (args) system;
        inherit inputs hostName;
      }
      // extraSpecialArgs;
  in
    inputs.nix-darwin.lib.darwinSystem {
      inherit (args) system;
      specialArgs =
        baseSpecialArgs
        // {
          inherit lib hostName;
          host.hostName = hostName;
        };
      modules =
        [
          {
            forge.security.agenix.enable = true;
            forge.security.sops.enable = true;
            nixpkgs.overlays = [config.flake.overlays.default] ++ extraOverlays;
            nixpkgs.config.allowUnfree = true;
            networking.hostName = hostName;
          }
          ./_darwin-tailscale.nix
          inputs.nix-homebrew.darwinModules.nix-homebrew
          config.flake.darwinModules.security_sops
          config.flake.darwinModules.security_agenix

          ./${hostName}
        ]
        ++ extraModules
        # NOTE You can also load all of your defined modules in the
        # following manner
        # ++ (lib.attrValues config.flake.darwinModules)
        ++ (
          if (withHomeManager && (lib.hasAttr "home-manager" inputs))
          then [
            inputs.home-manager.darwinModules.home-manager
            {
              home-manager = {
                backupFileExtension = ".before-nix-home-manager";
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = baseSpecialArgs;

                # NOTE You can also load all of your defined modules in the
                # following manner
                #
                sharedModules = lib.attrValues config.flake.homeModules;
              };
            }
          ]
          else []
        );
    };
in {
  flake.nixosConfigurations = {
    nook = withSystem "x86_64-linux" (
      args:
        mkHost args "nook" {
          withHomeManager = false;
        }
    );

    atlas = withSystem "x86_64-linux" (
      args:
        mkHost args "atlas" {
          withHomeManager = false;
          extraModules = [
            config.flake.nixosModules.services_auto-sync-update
            config.flake.nixosModules.services_authentik
            config.flake.nixosModules.services_forgejo-runner
            config.flake.nixosModules.services_matrix
            inputs.html-plans.nixosModules.default
            inputs.shop-empty-track.nixosModules.default
          ];
        }
    );
  };

  flake.darwinConfigurations = {
    vega = withSystem "aarch64-darwin" (
      args:
        mkDarwinHost args "vega" {
          withHomeManager = true;
          extraModules = [
            inputs.lix-module.darwinModules.default
          ];
        }
    );

    altair = withSystem "aarch64-darwin" (
      args:
        mkDarwinHost args "altair" {
          withHomeManager = true;
        }
    );
  };

  flake-file.inputs = {
    disko = {
      url = "github:nix-community/disko";
    };
    html-plans = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:LisaScheers/html-plans/main";
    };
    shop-empty-track = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:LisaScheers/shop-empty-track/main";
    };

    nix-darwin = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "https://flakehub.com/f/nix-darwin/nix-darwin/0.1.*";
    };
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    lix = {
      url = "https://git.lix.systems/lix-project/lix/archive/main.tar.gz";
      flake = false;
    };

    lix-module = {
      url = "https://git.lix.systems/lix-project/nixos-module/archive/main.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.lix.follows = "lix";
    };
    homebrew-cask = {
      flake = false;
      url = "github:homebrew/homebrew-cask";
    };
    homebrew-core = {
      flake = false;
      url = "github:homebrew/homebrew-core";
    };
    comic-code-fonts = {
      url = "github:LisaScheers/comic-code-fonts";
      flake = false;
    };
  };

  flake.checks.aarch64-darwin = {
    vega = config.flake.darwinConfigurations.vega.system;
  };

  # myExampleHost = withSystem "x86_64-linux" (
  #   args:
  #   mkHost args "myExampleHost" {
  #     withHomeManager = true;
  #     extraOverlays = with inputs; [
  #       neovim-nightly-overlay.overlays.default
  #       (final: _prev: { nur = import inputs.nur { pkgs = final; }; })
  #     ];
  #   }
  # );
  #};
}
