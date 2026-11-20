{
  config,
  lib,
  withSystem,
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
  checkSystems = builtins.filter (system: runners ? ${system}) (builtins.attrNames config.flake.checks);
  # Only these runners expose /dev/kvm, so their NixOS VM tests get a job of their own.
  kvmSystems = builtins.filter (system: builtins.elem system checkSystems) ["x86_64-linux"];
  dedicatedChecks = system: lib.concatMap (entry: entry.checks) (builtins.filter (entry: entry.system == system) config.ci.targets);
  unknownChecks = lib.concatMap (entry:
    map (name: "${entry.system}.${name}") (builtins.filter (name: !(config.flake.checks.${entry.system} ? ${name})) entry.checks))
  config.ci.targets;
  remainingChecks = system: removeAttrs config.flake.checks.${system} (dedicatedChecks system);
  isVmTest = check: lib.hasPrefix "vm-test-run-" check.name;
  linkChecks = name: system: checks: withSystem system ({pkgs, ...}: pkgs.linkFarm "${name}-${system}" checks);
in {
  options.ci.targets = lib.mkOption {
    type = lib.types.listOf (lib.types.submodule {
      options = {
        target = lib.mkOption {type = lib.types.str;};
        system = lib.mkOption {type = lib.types.enum (builtins.attrNames runners);};
        checks = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = "Flake checks for this system that share the target's closure; its job builds them and the per-system checks job skips them.";
        };
      };
    });
    default = [];
    description = "Build targets declared beside their host, home, or package output.";
  };
  # One job per system builds every remaining flake check, with VM tests split
  # out where KVM is available so slow tests fail separately from fast ones.
  config.flake.ciChecks = lib.genAttrs checkSystems (system:
    linkChecks "ci-checks" system (
      if builtins.elem system kvmSystems
      then lib.filterAttrs (_: check: !isVmTest check) (remainingChecks system)
      else remainingChecks system
    ));
  config.flake.ciVmTests =
    lib.genAttrs kvmSystems (system:
      linkChecks "ci-vm-tests" system (lib.filterAttrs (_: isVmTest) (remainingChecks system)));
  config.flake.ciMatrix.include = assert lib.assertMsg (unknownChecks == []) "ci.targets name unknown checks: ${toString unknownChecks}";
    map (entry: {
      inherit (entry) target;
      runner = runners.${entry.system};
      checks = lib.concatMapStringsSep " " (name: "checks.${entry.system}.${name}") entry.checks;
    })
    ordered
    ++ map (system: {
      target = "ciChecks.${system}";
      runner = runners.${system};
      checks = "";
    })
    checkSystems
    ++ map (system: {
      target = "ciVmTests.${system}";
      runner = runners.${system};
      checks = "";
    })
    kvmSystems;
}
