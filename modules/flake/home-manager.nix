{
  inputs,
  lib,
  ...
}: let
  settings = {
    backupFileExtension = "before-nix-home-manager";
    useGlobalPkgs = true;
    useUserPackages = true;
  };
in {
  options.flake.homeConfigurations = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.unspecified;
    default = {};
  };
  config = {
    nixos.home-manager = {
      imports = [inputs.home-manager.nixosModules.home-manager];
      home-manager = settings;
    };
    darwin.home-manager = {
      imports = [inputs.home-manager.darwinModules.home-manager];
      home-manager = settings;
    };
    flake-file.inputs.home-manager = {
      url = "github:LisaScheers/home-manager/agent/nushell-session-environment";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
