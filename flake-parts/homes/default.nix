# --- flake-parts/homes/default.nix
{
  lib,
  inputs,
  withSystem,
  config,
  ...
}: let
  mkHome = args: home: {
    extraSpecialArgs ? {},
    extraModules ? [],
    extraOverlays ? [],
    ...
  }:
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = import inputs.nixpkgs {
        inherit (args) system;
        overlays = [config.flake.overlays.default] ++ extraOverlays;
        config.allowUnfree = true;
      };
      extraSpecialArgs =
        {
          inherit (args) system;
          inherit inputs home;
        }
        // extraSpecialArgs;
      modules =
        [
          inputs.onepassword-shell-plugins.hmModules.default
          ./${home}
        ]
        ++ extraModules
        # NOTE You can also load all of your defined modules in the
        # following manner
        #
        ++ (lib.attrValues config.flake.homeModules);
    };
in {
  options.flake.homeConfigurations = lib.mkOption {
    type = with lib.types; lazyAttrsOf unspecified;
    default = {};
  };

  config = {
    # loop over all hosts and check if the user has a configuration for that host, if so, add it to the flake's homeConfigurations
    flake.homeConfigurations = {
      "lisa@vega" = withSystem "aarch64-darwin" (
        args:
          mkHome args "lisa@vega" {}
      );
      "lisa@nook" = withSystem "x86_64-linux" (
        args:
          mkHome args "lisa@nook" {}
      );
    };

    #{
    # "myUser@myHost" = withSystem "x86_64-linux" (
    #   args:
    #   mkHome args "myUser@myHost" {
    #     extraOverlays = with inputs; [
    #       neovim-nightly-overlay.overlays.default
    #       (final: _prev: { nur = import inputs.nur { pkgs = final; }; })
    #     ];
    # }
    # );

    #};

    flake.checks = {
      "aarch64-darwin" = {
        "home-lisa@vega" = config.flake.homeConfigurations."lisa@vega".config.home.path;
      };
      "x86_64-linux" = {
        "home-lisa@nook" = config.flake.homeConfigurations."lisa@nook".config.home.path;
      };
    };
  };
}
