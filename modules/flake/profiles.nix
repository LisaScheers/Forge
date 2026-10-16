{
  config,
  inputs,
  lib,
  ...
}: let
  profilesOf = class:
    lib.mkOption {
      type = lib.types.lazyAttrsOf (lib.types.deferredModuleWith {
        staticModules = [{_class = class;}];
      });
      default = {};
      description = "Class-checked " + class + " profiles, assembled by feature modules.";
    };
in {
  imports = [inputs.flake-parts.flakeModules.modules];
  options = {
    nixos = profilesOf "nixos";
    darwin = profilesOf "darwin";
    home = profilesOf "homeManager";
    overlays = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.raw;
      default = {};
      description = "Package overlays owned by their features.";
    };
    nginxErrorPage = lib.mkOption {
      type = lib.types.functionTo lib.types.attrs;
      description = "Shared Nginx error-page settings for a package set.";
    };
  };
  config.flake.modules = {
    nixos = config.nixos;
    darwin = config.darwin;
    homeManager = config.home;
  };
}
