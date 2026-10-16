{
  config,
  lib,
  ...
}: let
  runners = {
    x86_64-linux = "ubuntu-24.04";
    aarch64-linux = "ubuntu-24.04-arm";
    aarch64-darwin = "macos-15";
    x86_64-darwin = "macos-15-intel";
  };
  # Keep the published matrix ordered independently of module loading order.
  rank = target:
    if lib.hasPrefix "nixosConfigurations." target
    then "0"
    else if lib.hasPrefix "darwinConfigurations." target
    then "1"
    else if lib.hasPrefix "homeConfigurations." target
    then "2"
    else "3";
  ordered = builtins.sort (a: b: rank a.target + a.target < rank b.target + b.target) config.ci.targets;
in {
  options.ci.targets = lib.mkOption {
    type = lib.types.listOf (lib.types.submodule {
      options = {
        target = lib.mkOption {type = lib.types.str;};
        system = lib.mkOption {type = lib.types.enum (builtins.attrNames runners);};
      };
    });
    default = [];
    description = "Build targets declared beside their host, home, or package output.";
  };
  config.flake.ciMatrix.include =
    map (entry: {
      inherit (entry) target;
      runner = runners.${entry.system};
    })
    ordered;
}
