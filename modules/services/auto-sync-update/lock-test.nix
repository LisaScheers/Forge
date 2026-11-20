{
  config,
  withSystem,
  ...
}: {
  flake.checks.x86_64-linux.auto-sync-update-lock = withSystem "x86_64-linux" ({pkgs, ...}:
    pkgs.testers.runNixOSTest {
      name = "auto-sync-update-shared-lock";
      nodes.machine = {pkgs, ...}: {
        imports = [config.nixos.auto-sync-update];
        services.autoSyncUpdate = {
          repositoryPath = "/root/repository";
          flakeHost = "lock-fixture";
          environmentFile = "/run/auto-sync.env";
          emailTo = "";
          intervalSeconds = 86400;
          lockPath = "/run/shared-update.lock";
          rebuildCommand = [
            (toString (pkgs.writeShellScript "test-rebuild" ''
              touch /run/rebuild-start
              printf '%s\n' "$@" > /run/rebuild-args
              env > /run/rebuild-env
              if test -e /run/fail-rebuild; then exit 1; fi
              while ! test -e /run/allow-rebuild-finish; do sleep 0.1; done
              touch /run/rebuild-finished
            ''))
          ];
          rebootRequiredCommand = ["${pkgs.coreutils}/bin/false"];
        };
        # The test starts the unit more often than systemd's default start limit allows.
        systemd.services.nix-auto-sync-update.unitConfig.StartLimitIntervalSec = 0;
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

        with subtest("another holder of the lock file prevents updates"):
            machine.succeed("touch /run/shared-update.lock")
            machine.succeed("flock -n /run/shared-update.lock -c 'systemctl start nix-auto-sync-update.service'")
            assert machine.succeed("git -C /root/repository rev-parse HEAD").strip() == old
            machine.fail("test -e /run/rebuild-start")

        with subtest("the persistent file permits a later update after release"):
            machine.succeed("touch /run/allow-rebuild-finish")
            machine.succeed("systemctl start nix-auto-sync-update.service")
            assert machine.succeed("git -C /root/repository rev-parse HEAD").strip() == latest
            machine.succeed("test -f /run/shared-update.lock; test -f /run/rebuild-finished")
            # The rebuild gets the committed tree, with the ownership exception for Nix's git.
            assert machine.succeed("cat /run/rebuild-args").split() == ["--flake", f"git+file:///root/repository?rev={latest}#lock-fixture"]
            machine.succeed("grep -qx 'GIT_CONFIG_VALUE_0=/root/repository' /run/rebuild-env")

        with subtest("a running updater holds the lock until it finishes"):
            machine.succeed("rm /run/rebuild-start /run/rebuild-finished /run/allow-rebuild-finish")
            machine.succeed("systemctl start --no-block nix-auto-sync-update.service")
            machine.wait_for_file("/run/rebuild-start")
            machine.fail("flock -n /run/shared-update.lock -c true")
            machine.succeed("touch /run/allow-rebuild-finish")
            machine.wait_until_succeeds("test $(systemctl show nix-auto-sync-update.service -p ActiveState --value) = inactive")
            machine.succeed("flock -n /run/shared-update.lock -c true")

        with subtest("a failed rebuild fails the unit even without new commits"):
            machine.succeed("touch /run/fail-rebuild")
            machine.fail("systemctl start nix-auto-sync-update.service")
            machine.succeed("test $(systemctl show nix-auto-sync-update.service -p Result --value) = exit-code")
            machine.succeed("rm /run/fail-rebuild")
            machine.succeed("systemctl start nix-auto-sync-update.service")

        def last_run_log(expected):
            invocation = machine.succeed("systemctl show -p InvocationID --value nix-auto-sync-update.service").strip()
            query = f"journalctl --no-pager _SYSTEMD_INVOCATION_ID={invocation}"
            # journald may still be receiving the run's last lines.
            try:
                machine.wait_until_succeeds(f"{query} | grep -qF '{expected}'", timeout=30)
            except Exception:
                print(machine.succeed(f"{query}; journalctl --no-pager -u nix-auto-sync-update.service -n 40"))
                raise
            return machine.succeed(query)

        with subtest("the failure mail uses the SMTP settings from the environment file"):
            machine.succeed("echo AUTO_SYNC_SMTP_URL=smtp://127.0.0.1:9 > /run/auto-sync.env; touch /run/fail-rebuild")
            machine.fail("systemctl start nix-auto-sync-update.service")
            log = last_run_log("Failed to send email")
            assert "is not set" not in log, log
            machine.succeed("rm /run/fail-rebuild /run/auto-sync.env")

        with subtest("a pending reboot is scheduled once, even without a system change"):
            machine.succeed("echo AUTO_SYNC_FORCE_REBOOT_REQUIRED=1 > /run/auto-sync.env")
            machine.succeed("systemctl start nix-auto-sync-update.service")
            machine.succeed("systemctl is-active nix-auto-sync-update-reboot.timer")
            scheduled = machine.succeed("systemctl show -p ActiveEnterTimestampMonotonic --value nix-auto-sync-update-reboot.timer")
            machine.succeed("systemctl start nix-auto-sync-update.service")
            assert machine.succeed("systemctl show -p ActiveEnterTimestampMonotonic --value nix-auto-sync-update-reboot.timer") == scheduled
      '';
    });
}
