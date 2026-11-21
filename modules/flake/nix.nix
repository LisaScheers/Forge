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

  home.lisa = {
    lib,
    pkgs,
    osConfig ? null,
    ...
  }: {
    nix.package = lib.mkDefault (
      if osConfig != null
      then osConfig.nix.package
      # Standalone homes use Lix, as every host does.
      else pkgs.lixPackageSets.latest.lix
    );
    nix.nixPath = ["nixpkgs=${inputs.nixpkgs}"];
    nix.keepOldNixPath = false;
    # Home Manager writes ~/.config/nix/nix.conf from these; set user Nix
    # options here, never through xdg.configFile, which this would replace.
    nix.settings.nix-path = ["nixpkgs=${inputs.nixpkgs}"];
    nix.settings.experimental-features = ["nix-command" "flakes"];
    nix.registry.nixpkgs.flake = inputs.nixpkgs;
  };
}
