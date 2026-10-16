import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "scripts/deploy.sh"


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
  git:rev-parse) echo revision ;;
  ssh:atlas)
    if [[ "$*" == *'--property=ActiveState'* ]]; then echo inactive; fi
    ;;
  nix:run) exit "${DEPLOY_TEST_FAIL_ACTIVATION:-0}" ;;
esac
""")
        mock.chmod(0o755)
        for command in ("git", "ssh", "nix"):
            (self.root / command).symlink_to(mock)
        self.env = dict(os.environ, PATH=f"{self.root}:{os.environ['PATH']}",
                        DEPLOY_TEST_LOG=str(self.log))

    def run_deploy(self, *args, fail_activation=False):
        env = dict(self.env, DEPLOY_TEST_FAIL_ACTIVATION="1" if fail_activation else "0")
        result = subprocess.run(["bash", str(SCRIPT), *args], env=env,
                                text=True, capture_output=True, timeout=10)
        commands = self.log.read_text() if self.log.exists() else ""
        return result, commands

    def test_normal_success_restarts_updater(self):
        result, commands = self.run_deploy("atlas", "switch")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("nix run .#deploy", commands)
        self.assertIn("ssh atlas sudo systemctl start nix-auto-sync-update.timer", commands)

    def test_maintenance_success_keeps_updater_stopped(self):
        result, commands = self.run_deploy("atlas", "switch", "--maintenance")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("nix run .#deploy", commands)
        self.assertIn("ssh atlas sudo systemctl stop nix-auto-sync-update.timer", commands)
        self.assertEqual(commands.count("ssh atlas sudo systemctl stop nix-auto-sync-update.timer"), 2)
        self.assertNotIn("systemctl start nix-auto-sync-update.timer", commands)

    def test_failed_activation_keeps_updater_stopped(self):
        result, commands = self.run_deploy("atlas", "switch", "--maintenance", fail_activation=True)
        self.assertNotEqual(result.returncode, 0)
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


if __name__ == "__main__":
    unittest.main()
