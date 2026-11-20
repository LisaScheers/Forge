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
  systemsByRunner = lib.partition (system: runners ? ${system}) (builtins.attrNames config.flake.checks);
  checkSystems = systemsByRunner.right;
  unmappedSystems = systemsByRunner.wrong;
  # Only these runners expose /dev/kvm, so their NixOS VM tests get a job of their own.
  kvmSystems = builtins.filter (system: builtins.elem system checkSystems) ["x86_64-linux"];
  targetsOn = system: builtins.filter (entry: entry.system == system) config.ci.targets;
  dedicatedChecks = system: lib.concatMap (entry: entry.checks) (targetsOn system);
  missingChecks = entry: builtins.filter (name: !(config.flake.checks.${entry.system} ? ${name})) entry.checks;
  unknownChecks = lib.concatMap (entry: map (name: "${entry.system}.${name}") (missingChecks entry)) config.ci.targets;
  splitsOnSpaces = name: builtins.match ".*[[:space:]\"].*" name != null;
  unsafeCheckNames = builtins.filter splitsOnSpaces (lib.concatMap (entry: entry.checks) config.ci.targets);
  # The dev shell joins its system's checks job, so broken hooks or tools fail CI.
  devShell = system: let
    shells = config.flake.devShells.${system} or {};
  in
    lib.optionalAttrs (shells ? default) {dev-shell = shells.default;};
  remainingChecks = system: removeAttrs config.flake.checks.${system} (dedicatedChecks system) // devShell system;
  # Nixpkgs' runNixOSTest names a test with QEMU nodes vm-test-run-<name>, or
  # container-and-vm-test-run-<name> when it also has containers; container-only
  # tests need no KVM. ci-routing pins this on a real test and on fixtures.
  isVmTest = check: lib.any (prefix: lib.hasPrefix prefix check.name) ["vm-test-run-" "container-and-vm-test-run-"];
  # A VM test on a runner without KVM would build in an ordinary job. Target
  # checks may be host closures whose names need builds to read, so this runs
  # when the system's checks job is evaluated, not for the matrix.
  withoutVmTests = system: value: let
    vmTests = builtins.attrNames (lib.filterAttrs (_: isVmTest) config.flake.checks.${system});
  in
    assert lib.assertMsg (vmTests == []) "NixOS VM tests on ${system}, whose CI runner has no KVM: ${toString vmTests}"; value;
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
    description = "Build targets declared beside their home or package output; deploy.nix adds one per deployed host.";
  };
  # One job per system builds every remaining flake check, with VM tests split
  # out where KVM is available so slow tests fail separately from fast ones.
  config.flake.ciChecks = lib.genAttrs checkSystems (system:
    if builtins.elem system kvmSystems
    then linkChecks "ci-checks" system (lib.filterAttrs (_: check: !isVmTest check) (remainingChecks system))
    else withoutVmTests system (linkChecks "ci-checks" system (remainingChecks system)));
  config.flake.ciVmTests =
    lib.genAttrs kvmSystems (system:
      linkChecks "ci-vm-tests" system (lib.filterAttrs (_: isVmTest) (remainingChecks system)));
  config.flake.ciMatrix.include = assert lib.assertMsg (unknownChecks == []) "ci.targets name unknown checks: ${toString unknownChecks}";
  assert lib.assertMsg (unmappedSystems == []) "checks for systems without a CI runner: ${toString unmappedSystems}";
  # The job reads the check list as one space-separated string.
  assert lib.assertMsg (unsafeCheckNames == []) "ci.targets check names with whitespace or quotes: ${toString unsafeCheckNames}";
    map (entry: {
      inherit (entry) target;
      runner = runners.${entry.system};
      checks = lib.concatMapStringsSep " " (name: "checks.${entry.system}.\"${name}\"") entry.checks;
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
