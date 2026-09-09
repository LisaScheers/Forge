{
  config,
  lib,
  ...
}: let
  modulesOf = class:
    lib.mkOption {
      type = lib.types.lazyAttrsOf (lib.types.deferredModuleWith {
        staticModules = [{_class = class;}];
      });
      default = {};
      description = "Forge's ${class} compositions. Feature files merge into the composition they belong to.";
    };
in {
  options.forge = {
    overlays = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.raw;
      default = {};
      description = "Package overlays contributed by the feature that owns each package.";
    };
    hosts = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          class = lib.mkOption {type = lib.types.enum ["nixos" "darwin"];};
          system = lib.mkOption {type = lib.types.str;};
          module = lib.mkOption {type = lib.types.deferredModule;};
        };
      });
      default = {};
      description = "Machines managed by Forge, with their platform and selected composition.";
    };
    homes = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          system = lib.mkOption {type = lib.types.str;};
          module = lib.mkOption {type = lib.types.deferredModule;};
        };
      });
      default = {};
      description = "Standalone user environments, reusing the compositions embedded in hosts.";
    };
    modules = {
      nixos = modulesOf "nixos";
      darwin = modulesOf "darwin";
      homeManager = modulesOf "homeManager";
    };
    nginxErrorPage = lib.mkOption {
      type = lib.types.functionTo lib.types.attrs;
      description = "Shared Nginx error-page settings, parameterized by the consumer's package set.";
    };
  };

  # Public exports are an adapter; Forge's internal model lives in its own options.
  config.flake.modules = config.forge.modules;
}
