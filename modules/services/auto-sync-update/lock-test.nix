{
  config,
  inputs,
  ...
}: let
  pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
in {
  flake.checks.x86_64-linux.auto-sync-update-lock = pkgs.testers.runNixOSTest {
    name = "auto-sync-update-shared-lock";
    nodes.machine = {pkgs, ...}: {
      imports = [config.nixos.auto-sync-update];
      services.autoSyncUpdate = {
        repositoryPath = "/root/repository";
        flakeHost = "lock-fixture";
        environmentFile = "/dev/null";
        emailTo = "";
        intervalSeconds = 86400;
        lockDirectory = "/run/shared-update.lock";
        rebuildCommand = [
          (toString (pkgs.writeShellScript "test-rebuild" ''
            touch /run/rebuild-start
            while ! test -e /run/allow-rebuild-finish; do sleep 0.1; done
            touch /run/rebuild-finished
          ''))
        ];
        rebootRequiredCommand = ["${pkgs.coreutils}/bin/false"];
      };
      environment.systemPackages = [pkgs.git pkgs.util-linux];
      virtualisation.memorySize = 1024;
      system.stateVersion = "26.05";
    };
    testScript = ''
      start_all()
      machine.wait_for_unit("multi-user.target")
      machine.succeed("git init --bare --initial-branch=main /root/origin.git")
      machine.succeed("git init --initial-branch=main /root/seed")
      machine.succeed("git -C /root/seed config user.name Fixture; git -C /root/seed config user.email fixture@example.invalid")
      machine.succeed("echo base > /root/seed/value; git -C /root/seed add value; git -C /root/seed -c commit.gpgsign=false commit -m base")
      machine.succeed("git -C /root/seed remote add origin /root/origin.git; git -C /root/seed push origin main")
      machine.succeed("git clone /root/origin.git /root/repository")
      old = machine.succeed("git -C /root/repository rev-parse HEAD").strip()
      machine.succeed("echo update >> /root/seed/value; git -C /root/seed -c commit.gpgsign=false commit -am update; git -C /root/seed push origin main")
      latest = machine.succeed("git -C /root/seed rev-parse HEAD").strip()

      with subtest("a checkpoint holding the shared file prevents updates"):
          machine.succeed("touch /run/shared-update.lock")
          machine.succeed("flock -n /run/shared-update.lock -c 'systemctl start nix-auto-sync-update.service'")
          assert machine.succeed("git -C /root/repository rev-parse HEAD").strip() == old
          machine.fail("test -e /run/rebuild-start")

      with subtest("the persistent file permits a later update after release"):
          machine.succeed("touch /run/allow-rebuild-finish")
          machine.succeed("systemctl start nix-auto-sync-update.service")
          assert machine.succeed("git -C /root/repository rev-parse HEAD").strip() == latest
          machine.succeed("test -f /run/shared-update.lock; test -f /run/rebuild-finished")

      with subtest("a running updater excludes checkpoints until it finishes"):
          machine.succeed("rm /run/rebuild-start /run/rebuild-finished /run/allow-rebuild-finish")
          machine.succeed("systemctl start --no-block nix-auto-sync-update.service")
          machine.wait_for_file("/run/rebuild-start")
          machine.fail("flock -n /run/shared-update.lock -c true")
          machine.succeed("touch /run/allow-rebuild-finish")
          machine.wait_until_succeeds("test $(systemctl show nix-auto-sync-update.service -p ActiveState --value) = inactive")
          machine.succeed("flock -n /run/shared-update.lock -c true")
    '';
  };
}
