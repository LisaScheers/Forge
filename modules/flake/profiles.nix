{
  config,
  inputs,
  lib,
  options,
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
  };
  # Features bind themselves to profiles, so no file lists what a host gets;
  # `just features` prints the files that bind a profile, from this function.
  config.flake.lib.profileFiles = class: profile:
    assert lib.assertMsg (builtins.elem class ["nixos" "darwin" "home"]) "profileFiles: class must be nixos, darwin or home, not ${class}"; let
      relative = file: let
        inStore = builtins.match "${builtins.storeDir}/[^/]+/(.*)" (toString file);
      in
        if inStore == null
        then toString file
        else builtins.head inStore;
      binds = definition: definition.value ? ${profile};
    in
      lib.sort lib.lessThan (map (definition: relative definition.file) (lib.filter binds options.${class}.definitionsWithLocations));
  config.flake.modules = {
    inherit (config) nixos darwin;
    homeManager = config.home;
  };
}
