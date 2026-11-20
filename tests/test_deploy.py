import os
from pathlib import Path
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]
SCRIPT = REPO / "scripts/deploy.sh"


class DeployMaintenanceTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.log = self.root / "commands"
        mock = self.root / "mock"
        mock.write_text("""#!/usr/bin/env bash
set -euo pipefail
command_name=${0##*/}
printf '%s %s\\n' "$command_name" "$*" >> "$DEPLOY_TEST_LOG"
if [[ "$command_name" == ssh && "$1" == -S ]]; then shift 2; fi
case "$command_name:$1" in
  git:status) if [[ "${DEPLOY_TEST_DIRTY:-0}" == 1 ]]; then echo " M modules/example.nix"; fi ;;
  git:rev-parse)
    if [[ "$2" == origin/main ]]; then
      # Later lookups model main moving while the closures build.
      calls=$(( $(cat "$DEPLOY_TEST_ORIGIN_CALLS" 2>/dev/null || echo 0) + 1 ))
      echo "$calls" > "$DEPLOY_TEST_ORIGIN_CALLS"
      if (( calls == 1 )); then echo "${DEPLOY_TEST_ORIGIN_FIRST:-revision}"; else echo "${DEPLOY_TEST_ORIGIN_LATER:-revision}"; fi
    else
      echo revision
    fi
    ;;
  hostname:-s) echo "${DEPLOY_TEST_HOSTNAME:-vega}" ;;
  ssh:atlas)
    shift
    case "$*" in
      'sudo systemctl stop nix-auto-sync-update.timer')
        if [[ "${DEPLOY_TEST_FAIL_HOLD:-0}" == 1 && -f "$DEPLOY_TEST_TIMER" && "$(cat "$DEPLOY_TEST_TIMER")" == active ]]; then
          exit 1
        fi
        echo inactive > "$DEPLOY_TEST_TIMER"
        ;;
      'sudo systemctl start nix-auto-sync-update.timer') echo active > "$DEPLOY_TEST_TIMER" ;;
      *'ActiveState --value nix-auto-sync-update.timer') cat "$DEPLOY_TEST_TIMER" 2>/dev/null || echo "${DEPLOY_TEST_TIMER_INITIAL:-active}" ;;
      *'ActiveState --value nix-auto-sync-update.service') echo "${DEPLOY_TEST_UPDATER_STATE:-inactive}" ;;
      *'ActiveState --value nix-auto-sync-update-reboot.timer') echo "${DEPLOY_TEST_REBOOT_STATE:-inactive}" ;;
      *'--property=ActiveState'*) echo inactive ;;
    esac
    ;;
  nix:eval)
    [[ "$*" == *'.#deploySystems'* ]] || exit 1
    if [[ "${DEPLOY_TEST_FAIL_EVAL:-0}" == 1 ]]; then echo "error: flake evaluation failed" >&2; exit 1; fi
    case "$*" in
      *'systems."atlas"'*|*'systems."nook"'*) echo x86_64-linux ;;
      *'systems."vega"'*) echo aarch64-darwin ;;
    esac
    ;;
  nix:run)
    # NixOS activation can start the wanted timer before failing or rolling back.
    echo active > "$DEPLOY_TEST_TIMER"
    exit "${DEPLOY_TEST_FAIL_ACTIVATION:-0}"
    ;;
esac
""")
        mock.chmod(0o755)
        for command in ("git", "ssh", "nix", "hostname"):
            (self.root / command).symlink_to(mock)
        self.env = dict(os.environ, PATH=f"{self.root}:{os.environ['PATH']}",
                        DEPLOY_TEST_LOG=str(self.log),
                        DEPLOY_TEST_TIMER=str(self.root / "timer-state"),
                        DEPLOY_TEST_ORIGIN_CALLS=str(self.root / "origin-calls"))

    def run_deploy(self, *args, fail_activation=False, cwd=None):
        env = dict(self.env, DEPLOY_TEST_FAIL_ACTIVATION="1" if fail_activation else "0")
        result = subprocess.run(["bash", str(SCRIPT), *args], env=env, cwd=cwd,
                                text=True, capture_output=True, timeout=10)
        commands = self.log.read_text() if self.log.exists() else ""
        return result, commands

    def test_normal_success_restarts_updater(self):
        result, commands = self.run_deploy("atlas", "switch")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(f"nix run git+file://{REPO}?rev=revision#deploy", commands)
        self.assertIn("ssh atlas sudo systemctl start nix-auto-sync-update.timer", commands)

    def test_maintenance_success_keeps_updater_stopped(self):
        result, commands = self.run_deploy("atlas", "switch", "--maintenance")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(f"nix run git+file://{REPO}?rev=revision#deploy", commands)
        self.assertIn("ssh atlas sudo systemctl stop nix-auto-sync-update.timer", commands)
        self.assertEqual(commands.count("ssh atlas sudo systemctl stop nix-auto-sync-update.timer"), 2)
        self.assertNotIn("systemctl start nix-auto-sync-update.timer", commands)

    def test_a_held_timer_stays_stopped_after_an_aborted_or_successful_deploy(self):
        for updater_state in ("activating", "inactive"):
            with self.subTest(updater_state=updater_state):
                self.log.unlink(missing_ok=True)
                (self.root / "timer-state").unlink(missing_ok=True)
                self.env.update(DEPLOY_TEST_TIMER_INITIAL="inactive", DEPLOY_TEST_UPDATER_STATE=updater_state)
                result, commands = self.run_deploy("atlas", "switch")
                self.assertEqual(result.returncode, 0 if updater_state == "inactive" else 1, result.stderr)
                self.assertNotIn("systemctl start nix-auto-sync-update.timer", commands)
                self.assertEqual((self.root / "timer-state").read_text().strip(), "inactive")
                self.assertIn("was stopped before this deploy", result.stderr)

    def test_a_fixing_deploy_keeps_the_hold_left_by_a_failed_one(self):
        result, _ = self.run_deploy("atlas", "switch", fail_activation=True)
        self.assertNotEqual(result.returncode, 0)
        self.log.unlink()
        result, commands = self.run_deploy("atlas", "switch")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("systemctl start nix-auto-sync-update.timer", commands)
        self.assertEqual((self.root / "timer-state").read_text().strip(), "inactive")
        self.assertIn("sudo systemctl start nix-auto-sync-update.timer", result.stderr)

    def test_failed_activation_keeps_updater_stopped(self):
        for extra_args in ((), ("--maintenance",)):
            with self.subTest(extra_args=extra_args):
                self.log.unlink(missing_ok=True)
                result, commands = self.run_deploy("atlas", "switch", *extra_args, fail_activation=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual((self.root / "timer-state").read_text().strip(), "inactive")
                self.assertEqual(commands.count("ssh atlas sudo systemctl stop nix-auto-sync-update.timer"), 2)
                self.assertNotIn("systemctl start nix-auto-sync-update.timer", commands)

    def test_failed_timer_hold_is_reported_without_claiming_it_is_stopped(self):
        self.env["DEPLOY_TEST_FAIL_HOLD"] = "1"
        for extra_args in ((), ("--maintenance",)):
            with self.subTest(extra_args=extra_args):
                self.log.unlink(missing_ok=True)
                (self.root / "timer-state").unlink(missing_ok=True)
                result, commands = self.run_deploy("atlas", "switch", *extra_args, fail_activation=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual((self.root / "timer-state").read_text().strip(), "active")
                self.assertIn("failed to", result.stderr)
                self.assertNotIn("timer remains stopped", result.stderr)
                self.assertNotIn("systemctl start nix-auto-sync-update.timer", commands)

    def test_authenticated_channel_is_used_for_checks_and_activation(self):
        self.env["FORGE_DEPLOY_SSH_CONTROL"] = "/tmp/forge-test-socket"
        result, commands = self.run_deploy("atlas", "switch", "--maintenance")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("ssh -S /tmp/forge-test-socket atlas", commands)
        self.assertIn("--ssh-opts -S /tmp/forge-test-socket", commands)

    def test_maintenance_rejects_other_hosts_and_modes_before_contact(self):
        for args in (("nook", "switch", "--maintenance"),
                     ("atlas", "dry", "--maintenance"),
                     ("atlas", "switch", "--unknown")):
            with self.subTest(args=args):
                result, commands = self.run_deploy(*args)
                self.assertEqual(result.returncode, 2)
                self.assertEqual(commands, "")

    def test_evaluation_errors_are_not_reported_as_unknown_hosts(self):
        self.env["DEPLOY_TEST_FAIL_EVAL"] = "1"
        result, _ = self.run_deploy("atlas", "switch")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("flake evaluation failed", result.stderr)
        self.assertNotIn("unknown deploy host", result.stderr)

    def test_malformed_hosts_are_rejected_before_evaluation(self):
        for host in ('atlas"', "../atlas", ""):
            with self.subTest(host=host):
                result, commands = self.run_deploy(host, "switch")
                self.assertEqual(result.returncode, 2)
                self.assertIn("unknown deploy host", result.stderr)
                self.assertEqual(commands, "")

    def test_atlas_builds_and_activates_the_verified_commit(self):
        result, commands = self.run_deploy("atlas", "switch")
        self.assertEqual(result.returncode, 0, result.stderr)
        pinned = f"git+file://{REPO}?rev=revision"
        self.assertIn(f'{pinned}#checks.x86_64-linux."atlas"', commands)
        self.assertIn(f"{pinned}#atlas", commands)
        for line in commands.splitlines():
            if line.startswith(("nix build", "nix run")):
                self.assertNotIn(" .#", line)

    def test_a_failed_updater_does_not_block_a_fixing_deploy(self):
        self.env["DEPLOY_TEST_UPDATER_STATE"] = "failed"
        result, commands = self.run_deploy("atlas", "switch")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("nix run git+file://", commands)

    def test_the_pinned_url_encodes_the_checkout_path(self):
        checkout = self.root / "check out#1?"
        checkout.mkdir()
        result, commands = self.run_deploy("atlas", "switch", cwd=checkout)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("/check%20out%231%3F?rev=revision#atlas", commands)

    def test_running_updater_aborts_and_restarts_its_timer(self):
        self.env["DEPLOY_TEST_UPDATER_STATE"] = "active"
        result, commands = self.run_deploy("atlas", "switch")
        self.assertEqual(result.returncode, 1)
        self.assertIn("Atlas auto-update state is active", result.stderr)
        self.assertNotIn("nix run", commands)
        self.assertIn("ssh atlas sudo systemctl start nix-auto-sync-update.timer", commands)

    def assert_atlas_refused(self, message, *, built):
        result, commands = self.run_deploy("atlas", "switch")
        self.assertEqual(result.returncode, 1)
        self.assertIn(message, result.stderr)
        self.assertNotIn("nix run", commands)
        self.assertEqual("nix build" in commands, built)
        return commands

    def test_atlas_refuses_a_dirty_worktree(self):
        self.env["DEPLOY_TEST_DIRTY"] = "1"
        self.assert_atlas_refused("Atlas deploys require a clean worktree", built=False)

    def test_atlas_refuses_a_head_other_than_origin_main(self):
        self.env["DEPLOY_TEST_ORIGIN_FIRST"] = "elsewhere"
        self.assert_atlas_refused("Atlas deploys require HEAD to match origin/main", built=False)

    def test_atlas_refuses_when_main_moves_during_the_build(self):
        self.env["DEPLOY_TEST_ORIGIN_LATER"] = "elsewhere"
        commands = self.assert_atlas_refused("origin/main changed while building", built=True)
        self.assertIn("ssh atlas sudo systemctl start nix-auto-sync-update.timer", commands)

    def test_atlas_refuses_while_a_reboot_is_scheduled(self):
        self.env["DEPLOY_TEST_REBOOT_STATE"] = "active"
        commands = self.assert_atlas_refused("Atlas reboot timer state is active", built=True)
        self.assertIn("ssh atlas sudo systemctl start nix-auto-sync-update.timer", commands)

    def test_vega_deploys_only_from_vega_and_only_as_switch(self):
        self.env["DEPLOY_TEST_HOSTNAME"] = "nook"
        result, commands = self.run_deploy("vega", "switch")
        self.assertEqual(result.returncode, 2)
        self.assertIn("Vega can only be deployed manually from Vega", result.stderr)
        self.assertNotIn("nix build", commands)
        self.env["DEPLOY_TEST_HOSTNAME"] = "vega"
        result, commands = self.run_deploy("vega", "dry")
        self.assertEqual(result.returncode, 2)
        self.assertNotIn("nix build", commands)

    def test_other_hosts_map_modes_and_use_the_checkout(self):
        for mode, flag in (("dry", "--dry-activate"), ("test", "--test"), ("switch", None)):
            with self.subTest(mode=mode):
                self.log.unlink(missing_ok=True)
                result, commands = self.run_deploy("nook", mode)
                self.assertEqual(result.returncode, 0, result.stderr)
                run = next(line for line in commands.splitlines() if line.startswith("nix run"))
                self.assertIn(".#nook", run)
                if flag:
                    self.assertIn(flag, run)
                else:
                    self.assertNotIn("--dry-activate", run)
                    self.assertNotIn("--test", run)
                self.assertNotIn("ssh atlas", commands)

    def test_unknown_hosts_are_rejected(self):
        result, _ = self.run_deploy("altair", "switch")
        self.assertEqual(result.returncode, 2)
        self.assertIn("unknown deploy host: altair", result.stderr)


if __name__ == "__main__":
    unittest.main()
