{
  config,
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
        mixed = stub "container-and-vm-test-run-mixed";
        container = stub "container-test-run-container";
        # A container-only test whose own name contains the VM marker.
        tricky = stub "container-test-run-vm-test-run-metadata";
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
  # Checks for a platform with no runner.
  unmapped = fixture [] {flake.checks.riscv64-linux.unit = stub "unit-tests";};
  # A VM test on a runner without KVM, in the checks job or a target's job.
  vmWithoutKvm = targetChecks: vmName:
    fixture [] {
      systems = ["x86_64-linux" "aarch64-linux"];
      flake.checks.aarch64-linux.vm = stub vmName;
      ci.targets = [
        {
          target = "nixosConfigurations.arm";
          system = "aarch64-linux";
          checks = targetChecks;
        }
      ];
    };
  evaluatesArmChecks = targetChecks: vmName: (builtins.tryEval (vmWithoutKvm targetChecks vmName).ciChecks.aarch64-linux.name).success;
  # The same fixture with an ordinary check evaluates, so a rejection is the guard's.
  rejectsVm = targetChecks:
    evaluatesArmChecks targetChecks "unit-tests"
    && !(evaluatesArmChecks targetChecks "vm-test-run-vm")
    && !(evaluatesArmChecks targetChecks "container-and-vm-test-run-mixed");
  entries = output: builtins.attrNames output.x86_64-linux.entries;
  # Each failure names the rule it broke.
  rules = [
    {
      holds = config.flake.checks.x86_64-linux.auto-sync-update.name == "vm-test-run-auto-sync-update";
      message = "runNixOSTest no longer names QEMU tests vm-test-run-<name>; update isVmTest in ci.nix";
    }
    {
      holds =
        map (entry: entry.target) routed.ciMatrix.include
        == ["nixosConfigurations.host" "ciChecks.x86_64-linux" "ciVmTests.x86_64-linux"];
      message = "each target, the regular checks and the VM tests need their own jobs";
    }
    {
      # Quoted so dotted names stay one attribute.
      holds =
        (builtins.head routed.ciMatrix.include).checks
        == ''checks.x86_64-linux."host" checks.x86_64-linux."deploy" checks.x86_64-linux."dotted.name"'';
      message = "a target's job must build the checks it lists, each quoted";
    }
    {
      holds = entries routed.ciChecks == ["container" "tricky" "unit"] && entries routed.ciVmTests == ["mixed" "vm"];
      message = "VM tests, mixed container-and-VM tests included, must leave the regular checks job, and only they";
    }
    {
      holds = !(builtins.tryEval (builtins.deepSeq (fixture ["missing"] {}).ciMatrix true)).success;
      message = "ci.targets must reject unknown checks";
    }
    {
      holds = !(builtins.tryEval (builtins.deepSeq unmapped.ciMatrix true)).success;
      message = "checks for a platform without a runner must fail evaluation";
    }
    {
      holds = rejectsVm [] && rejectsVm ["vm"];
      message = "a VM test on a runner without KVM must fail that platform's checks job";
    }
  ];
  broken = map (rule: rule.message) (builtins.filter (rule: !rule.holds) rules);
in {
  perSystem = {pkgs, ...}: {
    checks.ci-routing = assert lib.assertMsg (broken == []) "ci-routing: ${lib.concatStringsSep "; " broken}";
      pkgs.runCommand "ci-routing" {} ''
        touch "$out"
      '';
  };
}
