{
  config,
  inputs,
  ...
}: let
  base = {pkgs, ...}: {
    # Lix releases from Nixpkgs are built by Hydra and come from cache.nixos.org.
    nix.package = pkgs.lixPackageSets.latest.lix;
    nixpkgs.config.allowUnfree = true;
    nixpkgs.overlays = [config.flake.overlays.default];
    nix.nixPath = ["nixpkgs=${inputs.nixpkgs}"];
    nix.settings.nix-path = ["nixpkgs=${inputs.nixpkgs}"];
    nix.registry.nixpkgs.flake = inputs.nixpkgs;
  };
in {
  nixos.base = base;
  darwin.base = base;

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
}
