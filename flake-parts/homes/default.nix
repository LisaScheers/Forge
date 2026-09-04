{
  config,
  inputs,
  lib,
  ...
}: let
  mkHome = system: module:
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [config.flake.overlays.default];
        config.allowUnfree = true;
      };
      modules = [module];
    };
in {
  options.flake.homeConfigurations = lib.mkOption {
    type = with lib.types; lazyAttrsOf unspecified;
    default = {};
  };

  config = {
    flake.homeConfigurations = {
      "lisa@vega" = mkHome "aarch64-darwin" config.flake.modules.homeManager."lisa@vega";
      "lisa@nook" = mkHome "x86_64-linux" config.flake.modules.homeManager."lisa@nook";
    };

    flake.checks = {
      aarch64-darwin."home-lisa@vega" = config.flake.homeConfigurations."lisa@vega".config.home.path;
      x86_64-linux."home-lisa@nook" = config.flake.homeConfigurations."lisa@nook".config.home.path;
    };

    flake-file.inputs = {
      home-manager = {
        url = "github:LisaScheers/home-manager/agent/nushell-session-environment";
        inputs.nixpkgs.follows = "nixpkgs";
      };
      onepassword-shell-plugins = {
        url = "github:1Password/shell-plugins";
        inputs.nixpkgs.follows = "nixpkgs";
      };
    };
  };
}
