{
  config,
  withSystem,
  ...
}: {
  flake.checks.x86_64-linux.auto-sync-update = withSystem "x86_64-linux" ({pkgs, ...}:
    pkgs.testers.runNixOSTest {
      name = "auto-sync-update";
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
              if test -e /run/fail-rebuild; then echo rebuild-failure-marker; exit "$(cat /run/fail-rebuild)"; fi
              while ! test -e /run/allow-rebuild-finish; do sleep 0.1; done
              touch /run/rebuild-finished
            ''))
          ];
          rebootRequiredCommand = [(toString (pkgs.writeShellScript "test-reboot-required" "test -e /run/reboot-required"))];
        };
        # The checkout belongs to another user, as on Atlas, so Git's
        # ownership check applies.
        users.users.fixture.isNormalUser = true;
        # The real fetch subtest uses Lix, as Atlas does.
        nix.package = pkgs.lixPackageSets.latest.lix;
        nix.settings.experimental-features = ["nix-command" "flakes"];
        # The test starts the unit more often than systemd's default start limit allows.
        systemd.services.nix-auto-sync-update.unitConfig.StartLimitIntervalSec = 0;
        environment.systemPackages = [pkgs.git pkgs.python3 pkgs.util-linux];
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
        machine.succeed("git clone /root/origin.git /root/repository; chown -R fixture /root/repository")
        old = machine.succeed("git -c safe.directory='*' -C /root/repository rev-parse HEAD").strip()
        machine.succeed("echo update >> /root/seed/value; git -C /root/seed -c commit.gpgsign=false commit -am update; git -C /root/seed push origin main")
        latest = machine.succeed("git -C /root/seed rev-parse HEAD").strip()

        with subtest("another holder of the lock file prevents updates"):
            machine.succeed("touch /run/shared-update.lock")
            machine.succeed("flock -n /run/shared-update.lock -c 'systemctl start nix-auto-sync-update.service'")
            assert machine.succeed("git -c safe.directory='*' -C /root/repository rev-parse HEAD").strip() == old
            machine.fail("test -e /run/rebuild-start")

        with subtest("the persistent file permits a later update after release"):
            machine.succeed("touch /run/allow-rebuild-finish")
            machine.succeed("systemctl start nix-auto-sync-update.service")
            assert machine.succeed("git -c safe.directory='*' -C /root/repository rev-parse HEAD").strip() == latest
            machine.succeed("test -f /run/shared-update.lock; test -f /run/rebuild-finished")
            # The rebuild gets the committed tree.
            assert machine.succeed("cat /run/rebuild-args").split() == ["--flake", f"git+file:///root/repository?rev={latest}#lock-fixture"]

        with subtest("a running updater holds the lock until it finishes"):
            machine.succeed("rm /run/rebuild-start /run/rebuild-finished /run/allow-rebuild-finish")
            machine.succeed("systemctl start --no-block nix-auto-sync-update.service")
            machine.wait_for_file("/run/rebuild-start")
            machine.fail("flock -n /run/shared-update.lock -c true")
            machine.succeed("touch /run/allow-rebuild-finish")
            machine.wait_until_succeeds("test $(systemctl show nix-auto-sync-update.service -p ActiveState --value) = inactive")
            machine.succeed("flock -n /run/shared-update.lock -c true")

        with subtest("a failed rebuild fails the unit even without new commits"):
            machine.succeed("echo 1 > /run/fail-rebuild")
            machine.fail("systemctl start nix-auto-sync-update.service")
            machine.succeed("test $(systemctl show nix-auto-sync-update.service -p Result --value) = exit-code")
            machine.succeed("rm /run/fail-rebuild")
            machine.succeed("systemctl start nix-auto-sync-update.service")

        machine.succeed("systemd-run --unit smtp-fixture python3 ${./smtp-fixture.py}")
        machine.wait_for_open_port(2525)
        smtp = "AUTO_SYNC_SMTP_URL=smtp://127.0.0.1:2525\nAUTO_SYNC_SMTP_REQUIRE_TLS=0\n"

        with subtest("the failure mail carries the full log and the exit status"):
            machine.succeed(f"printf '{smtp}' > /run/auto-sync.env; echo 1 > /run/fail-rebuild")
            machine.fail("systemctl start nix-auto-sync-update.service")
            machine.wait_until_succeeds("grep -q rebuild-failure-marker /run/mail.txt", timeout=30)
            mail = machine.succeed("cat /run/mail.txt")
            assert "failed on lock-fixture with exit status 1" in mail, mail
            machine.succeed("rm /run/fail-rebuild /run/mail.txt")

        with subtest("the environment file is read as data, never run"):
            # A command line is not an assignment: systemd skips it and the
            # updater still mails with the file's SMTP settings.
            machine.succeed(f"printf 'touch /run/env-file-ran\\n{smtp}' > /run/auto-sync.env; echo 1 > /run/fail-rebuild")
            machine.fail("systemctl start nix-auto-sync-update.service")
            machine.wait_until_succeeds("grep -q rebuild-failure-marker /run/mail.txt", timeout=30)
            machine.fail("test -e /run/env-file-ran")
            machine.succeed("rm /run/fail-rebuild /run/mail.txt /run/auto-sync.env")

        with subtest("an environment file without an SMTP URL fails visibly"):
            # A malformed line is skipped by systemd, which would lose mail silently.
            machine.succeed("printf 'export AUTO_SYNC_SMTP_URL=smtp://127.0.0.1:2525\\n' > /run/auto-sync.env; touch /run/reboot-required")
            machine.fail("systemctl start nix-auto-sync-update.service")
            invocation = machine.succeed("systemctl show -p InvocationID --value nix-auto-sync-update.service").strip()
            run_log = f"journalctl --no-pager _SYSTEMD_INVOCATION_ID={invocation}"
            machine.wait_until_succeeds(f"{run_log} | grep -q 'Not sending the failure mail'", timeout=30)
            # Reported once: the failure mail does not repeat the same complaint.
            assert machine.succeed(f"{run_log} | grep -c 'AUTO_SYNC_SMTP_URL is not set'").strip() == "1"
            machine.succeed("rm /run/reboot-required")
            machine.succeed("systemctl stop nix-auto-sync-update-reboot.timer || true")

        with subtest("an undeliverable reboot notice fails the unit"):
            machine.succeed("printf 'AUTO_SYNC_SMTP_URL=smtp://127.0.0.1:9\\nAUTO_SYNC_SMTP_REQUIRE_TLS=0\\n' > /run/auto-sync.env; touch /run/reboot-required")
            machine.fail("systemctl start nix-auto-sync-update.service")
            invocation = machine.succeed("systemctl show -p InvocationID --value nix-auto-sync-update.service").strip()
            run_log = f"journalctl --no-pager _SYSTEMD_INVOCATION_ID={invocation}"
            machine.wait_until_succeeds(f"{run_log} | grep -q 'Not sending the failure mail'", timeout=30)
            # One attempt only: the failure mail is not retried against the same server.
            assert machine.succeed(f"{run_log} | grep -c 'Failed to send email'").strip() == "1"
            machine.succeed("rm /run/reboot-required")
            machine.succeed("systemctl stop nix-auto-sync-update-reboot.timer || true")

        with subtest("a failed rebuild keeps its exit status when the mail cannot be sent"):
            # Both ways mail fails: no SMTP URL, and a server that refuses the connection.
            for env in ["AUTO_SYNC_SMTP_REQUIRE_TLS=0\\n", "AUTO_SYNC_SMTP_URL=smtp://127.0.0.1:9\\nAUTO_SYNC_SMTP_REQUIRE_TLS=0\\n"]:
                machine.succeed(f"printf '{env}' > /run/auto-sync.env; echo 23 > /run/fail-rebuild")
                machine.fail("systemctl start nix-auto-sync-update.service")
                assert machine.succeed("systemctl show -p ExecMainStatus --value nix-auto-sync-update.service").strip() == "23", env
            machine.succeed("rm /run/fail-rebuild /run/auto-sync.env")

        with subtest("a Git token run leaves no temporary files behind"):
            machine.succeed("printf 'AUTO_SYNC_GIT_TOKEN=fixture-token\\n' > /run/auto-sync.env; rm -rf /tmp/tmp.*")
            machine.succeed("systemctl start nix-auto-sync-update.service")
            # The askpass helper, log and mail marker all lived in one private directory.
            machine.succeed("test -z \"$(ls -A /tmp | grep '^tmp\\.')\"")
            machine.succeed("rm /run/auto-sync.env")

        with subtest("Lix fetches a pinned revision from a checkout root does not own"):
            machine.succeed(
                "mkdir /root/flake && cp ${pkgs.writeText "flake.nix" "{outputs = _: {answer = \"42\";};}"} /root/flake/flake.nix"
                " && git -C /root/flake init -q && git -C /root/flake add flake.nix"
                " && git -C /root/flake -c user.name=x -c user.email=x@example.invalid -c commit.gpgsign=false commit -qm flake"
                " && chown -R fixture /root/flake"
            )
            rev = machine.succeed("git -c safe.directory='*' -C /root/flake rev-parse HEAD").strip()
            url = f"git+file:///root/flake?rev={rev}#answer"
            # No safe.directory exception: this is what the updater's rebuild relies on.
            assert machine.succeed(f"nix eval --raw '{url}'") == "42"

        with subtest("local commits that are not on origin are never rebuilt"):
            machine.succeed("git -c safe.directory='*' -C /root/repository -c user.name=x -c user.email=x@example.invalid -c commit.gpgsign=false commit --allow-empty -m local")
            machine.succeed("rm -f /run/rebuild-start")
            machine.fail("systemctl start nix-auto-sync-update.service")
            machine.fail("test -e /run/rebuild-start")
            machine.succeed("journalctl -u nix-auto-sync-update.service | grep -q 'not on origin/main'")
            machine.succeed("git -c safe.directory='*' -C /root/repository reset --hard origin/main")

        with subtest("a pending reboot is scheduled once, even without a system change"):
            machine.succeed("touch /run/reboot-required")
            machine.succeed("systemctl start nix-auto-sync-update.service")
            machine.succeed("systemctl is-active nix-auto-sync-update-reboot.timer")
            scheduled = machine.succeed("systemctl show -p ActiveEnterTimestampMonotonic --value nix-auto-sync-update-reboot.timer")
            machine.succeed("systemctl start nix-auto-sync-update.service")
            assert machine.succeed("systemctl show -p ActiveEnterTimestampMonotonic --value nix-auto-sync-update-reboot.timer") == scheduled
      '';
    });
}
