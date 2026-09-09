{
  config,
  inputs,
  lib,
  ...
}: let
  overlay = lib.composeManyExtensions (lib.attrValues config.forge.overlays);
in {
  flake.overlays = config.forge.overlays // {default = overlay;};
  perSystem = {system, ...}: {
    _module.args.pkgs = import inputs.nixpkgs {
      inherit system;
      overlays = [overlay];
      config.allowUnfree = true;
    };
  };
}
