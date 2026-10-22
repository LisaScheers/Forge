{
  config,
  inputs,
  ...
}: let
  base = class: {
    imports = [inputs.lix-module.${class + "Modules"}.default];
    nixpkgs.config.allowUnfree = true;
    nixpkgs.overlays = [config.flake.overlays.default];
    nix.nixPath = ["nixpkgs=${inputs.nixpkgs}"];
    nix.settings.nix-path = ["nixpkgs=${inputs.nixpkgs}"];
    nix.registry.nixpkgs.flake = inputs.nixpkgs;
  };
in {
  nixos.base = base "nixos";
  darwin.base = base "darwin";

  home.lisa-cli = {
    lib,
    pkgs,
    osConfig ? null,
    ...
  }: {
    nix.package = lib.mkDefault (
      if osConfig != null
      then osConfig.nix.package
      else pkgs.nix
    );
    nix.nixPath = ["nixpkgs=${inputs.nixpkgs}"];
    nix.keepOldNixPath = false;
    nix.settings.nix-path = ["nixpkgs=${inputs.nixpkgs}"];
    nix.registry.nixpkgs.flake = inputs.nixpkgs;
  };

  flake-file.inputs = {
    lix-module = {
      url = "https://git.lix.systems/lix-project/nixos-module/archive/main.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.lix.follows = "lix";
    };
    lix = {
      url = "https://git.lix.systems/lix-project/lix/archive/main.tar.gz";
      flake = false;
    };
  };
}
