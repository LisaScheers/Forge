{
  config,
  inputs,
  lib,
  ...
}: let
  overlay = lib.composeManyExtensions (lib.attrValues config.overlays);
in {
  flake.overlays = config.overlays // {default = overlay;};
  perSystem = {system, ...}: {
    _module.args.pkgs = import inputs.nixpkgs {
      inherit system;
      overlays = [overlay];
      config.allowUnfree = true;
    };
  };
}
