{
  inputs,
  lib,
  ...
}: let
  stub = name: {
    type = "derivation";
    inherit name;
    outPath = builtins.toFile name "";
  };
  fixture = targetChecks: extra:
    (inputs.flake-parts.lib.evalFlakeModule {inherit inputs;} {
      imports = [./ci.nix extra];
      systems = ["x86_64-linux"];
      flake.checks.x86_64-linux = {
        host = stub "nixos-system-host";
        deploy = stub "deploy-rs-check-activate";
        "dotted.name" = stub "dotted";
        unit = stub "unit-tests";
        vm = stub "vm-test-run-vm";
      };
      ci.targets = [
        {
          target = "nixosConfigurations.host";
          system = "x86_64-linux";
          checks = targetChecks;
        }
      ];
    })
    .config
    .flake;
  routed = fixture ["host" "deploy" "dotted.name"] {};
  # Checks for a platform with no runner and no unbuilt exemption.
  unmapped = fixture [] {flake.checks.riscv64-linux.unit = stub "unit-tests";};
  # A VM test on a runner without KVM, in the checks job or a target's job.
  vmWithoutKvm = targetChecks:
    fixture [] {
      systems = ["x86_64-linux" "aarch64-linux"];
      flake.checks.aarch64-linux.vm = stub "vm-test-run-vm";
      ci.targets = [
        {
          target = "nixosConfigurations.arm";
          system = "aarch64-linux";
          checks = targetChecks;
        }
      ];
    };
  rejectsVm = targetChecks: !(builtins.tryEval (vmWithoutKvm targetChecks).ciChecks.aarch64-linux.name).success;
  entries = output: builtins.attrNames output.x86_64-linux.entries;
  valid =
    map (entry: entry.target) routed.ciMatrix.include
    == ["nixosConfigurations.host" "ciChecks.x86_64-linux" "ciVmTests.x86_64-linux"]
    # Target checks build in the target's job, quoted so dotted names stay one attribute.
    && (builtins.head routed.ciMatrix.include).checks
    == ''checks.x86_64-linux."host" checks.x86_64-linux."deploy" checks.x86_64-linux."dotted.name"''
    && entries routed.ciChecks == ["unit"]
    && entries routed.ciVmTests == ["vm"]
    && !(builtins.tryEval (builtins.deepSeq (fixture ["missing"] {}).ciMatrix true)).success
    && !(builtins.tryEval (builtins.deepSeq unmapped.ciMatrix true)).success
    && rejectsVm []
    && rejectsVm ["vm"];
in {
  perSystem = {pkgs, ...}: {
    checks.ci-routing = assert lib.assertMsg valid "CI must route target, regular and VM checks to separate jobs and reject unknown checks, unmapped platforms and VM tests without KVM";
      pkgs.runCommand "ci-routing" {} ''
        touch "$out"
      '';
  };
}
