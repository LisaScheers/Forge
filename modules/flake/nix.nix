{
  config,
  inputs,
  ...
}: let
  base = class: {
    imports = [inputs.lix-module.${class + "Modules"}.default];
    nixpkgs.config.allowUnfree = true;
    nixpkgs.overlays = [config.flake.overlays.default];
  };
in {
  nixos.base = base "nixos";
  darwin.base = base "darwin";

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
