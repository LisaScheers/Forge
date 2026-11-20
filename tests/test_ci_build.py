"""Check CI download recovery and failure propagation without real builds."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / ".github/scripts/build-configuration.sh"


class CiBuildTest(unittest.TestCase):
    def run_build(self, message, failures=1, checks=None):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            attempts = root / "attempts"
            attempts.write_text("0")
            nix = root / "nix"
            nix.write_text('''#!/usr/bin/env bash
printf '%s\n' "$@" > "$ARGS_FILE"
count=$(<"$ATTEMPTS_FILE")
count=$((count + 1))
echo "$count" > "$ATTEMPTS_FILE"
if (( count <= FAIL_ATTEMPTS )); then
  echo "$FAIL_MESSAGE" >&2
  exit 77
fi
''')
            nix.chmod(0o755)
            sleep = root / "sleep"
            sleep.write_text("#!/usr/bin/env bash\nexit 0\n")
            sleep.chmod(0o755)
            result = subprocess.run(
                ["bash", str(SCRIPT)], capture_output=True, text=True,
                env={
                    **os.environ,
                    "PATH": str(root) + os.pathsep + os.environ["PATH"],
                    "TARGET": "test-target",
                    "ATTEMPTS_FILE": str(attempts),
                    "FAIL_ATTEMPTS": str(failures),
                    "FAIL_MESSAGE": message,
                    "ARGS_FILE": str(root / "args"),
                    **({"CHECKS": checks} if checks else {}),
                },
            )
            self.args = (root / "args").read_text().splitlines()
            return result, int(attempts.read_text())

    def test_checks_build_with_the_target(self):
        result, _ = self.run_build("", failures=0, checks="checks.x86_64-linux.a checks.x86_64-linux.b")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual(self.args[-3:], [".#test-target", ".#checks.x86_64-linux.a", ".#checks.x86_64-linux.b"])

    def test_transient_download_errors_recover(self):
        for message in (
            "curl: (6) Could not resolve host: example.org",
            "error: unable to download 'https://cache.nixos.org/nar/example.nar.zst': HTTP error 416 ()",
        ):
            with self.subTest(message=message):
                result, attempts = self.run_build(message)
                self.assertEqual(result.returncode, 0, result.stdout)
                self.assertEqual(attempts, 2)

    def test_retries_stop_after_three_attempts(self):
        result, attempts = self.run_build(
            "error: unable to download 'https://cache.nixos.org/nar/example.nar.zst': HTTP error 416 ()",
            failures=4,
        )
        self.assertEqual(result.returncode, 77)
        self.assertEqual(attempts, 3)

    def test_other_failures_are_immediate(self):
        for message in (
            "error: builder failed with exit code 1",
            "error: hash mismatch in fixed-output derivation",
            "error: unable to download 'https://cache.nixos.org/nar/example.nar.zst': HTTP error 403 ()",
        ):
            with self.subTest(message=message):
                result, attempts = self.run_build(message)
                self.assertEqual(result.returncode, 77)
                self.assertEqual(attempts, 1)


if __name__ == "__main__":
    unittest.main()
