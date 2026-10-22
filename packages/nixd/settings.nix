{
  lib,
  pkgs,
  forge,
}: let
  flake = "(builtins.getFlake ${builtins.toJSON (toString forge)})";
  homeName =
    if pkgs.stdenv.hostPlatform.isDarwin
    then "lisa@vega"
    else if pkgs.stdenv.hostPlatform.isAarch64
    then "lisa@asterion"
    else "lisa@nook";
in {
  nixpkgs.expr = "import <nixpkgs> { }";
  formatting.command = ["${lib.getExe pkgs.nixfmt}"];
  options = {
    nixos.expr = "${flake}.nixosConfigurations.atlas.options";
    darwin.expr = "${flake}.darwinConfigurations.vega.options";
    home-manager.expr = "${flake}.homeConfigurations.${builtins.toJSON homeName}.options";
    flake-parts.expr = "${flake}.debug.options";
    flake-file.expr = "${flake}.debug.options.flake-file.type.getSubOptions []";
    devenv.expr = "{ devenv.shells.default = ${flake}.allSystems.${builtins.toJSON pkgs.stdenv.hostPlatform.system}.options.devenv.shells.type.getSubOptions []; }";
  };
}
