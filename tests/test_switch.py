"""Check local switch routing without activating a system."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


JUSTFILE = Path(__file__).resolve().parents[1] / "Justfile"


class SwitchTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.checkout = self.root / "checkout with spaces"
        self.checkout.mkdir()
        shutil.copy(JUSTFILE, self.checkout / "Justfile")
        self.log = self.root / "commands"
        mock = self.root / "mock"
        mock.write_text('''#!/usr/bin/env bash
set -euo pipefail
case "${0##*/}" in
  uname) echo "$SWITCH_TEST_OS" ;;
  hostname) echo "$SWITCH_TEST_HOST" ;;
  sudo) echo 'unwrapped sudo was selected' >&2; exit 99 ;;
  *) printf '%s\\n' "${0##*/}" "$@" >> "$SWITCH_TEST_LOG"
     exit "${SWITCH_TEST_EXIT:-0}" ;;
esac
''')
        mock.chmod(0o755)
        for command in ("uname", "hostname", "sudo", "sudo-wrapper", "open"):
            (self.root / command).symlink_to(mock)
        self.bash_env = self.root / "bash-env"
        self.bash_env.write_text('''# Intercept the privileged boundary without running real sudo.
function /run/wrappers/bin/sudo() {
  "$SWITCH_TEST_BIN/sudo-wrapper" "$@"
}
''')

    def run_switch(self, system, host, exit_code=0):
        result = subprocess.run(
            ["just", "--justfile", str(self.checkout / "Justfile"), "switch"],
            env=dict(os.environ, PATH=f"{self.root}:{os.environ['PATH']}",
                     BASH_ENV=str(self.bash_env), SWITCH_TEST_BIN=str(self.root),
                     SWITCH_TEST_OS=system, SWITCH_TEST_HOST=host,
                     SWITCH_TEST_LOG=str(self.log), SWITCH_TEST_EXIT=str(exit_code)),
            text=True, capture_output=True, timeout=10,
        )
        commands = self.log.read_text().splitlines() if self.log.exists() else []
        return result, commands

    def test_asterion_uses_privileged_wrapper_despite_unwrapped_sudo_on_path(self):
        result, commands = self.run_switch("Linux", "asterion")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(commands, [
            "sudo-wrapper", "nixos-rebuild", "switch", "--flake",
            f"path:{self.checkout}#asterion",
        ])

    def test_vega_opens_apple_terminal(self):
        result, commands = self.run_switch("Darwin", "vega")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(commands, [
            "open", "-b", "com.apple.Terminal",
            str(self.checkout / "scripts/switch-vega.command"),
        ])

    def test_other_hosts_and_mismatched_systems_are_rejected(self):
        for system, host in (("Linux", "atlas"), ("Linux", "vega"),
                             ("Darwin", "asterion")):
            with self.subTest(system=system, host=host):
                result, commands = self.run_switch(system, host)
                self.assertEqual(result.returncode, 2)
                self.assertIn("must run on Vega or Asterion", result.stderr)
                self.assertEqual(commands, [])

    def test_command_failures_propagate(self):
        for system, host in (("Linux", "asterion"), ("Darwin", "vega")):
            with self.subTest(system=system, host=host):
                result, _ = self.run_switch(system, host, exit_code=37)
                self.assertEqual(result.returncode, 37)


if __name__ == "__main__":
    unittest.main()
