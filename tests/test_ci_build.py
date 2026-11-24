"""Check CI download recovery and failure propagation without real builds."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / ".github/scripts/build-configuration.sh"


class CiBuildTest(unittest.TestCase):
    shell = "bash"

    def run_build(self, message, failures=1, checks="", target="test-target"):
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
                [self.shell, str(SCRIPT)], capture_output=True, text=True,
                env={
                    # Never inherit the caller's TARGET or CHECKS.
                    **{key: value for key, value in os.environ.items() if key not in ("TARGET", "CHECKS")},
                    "PATH": str(root) + os.pathsep + os.environ["PATH"],
                    **({"TARGET": target} if target else {}),
                    "ATTEMPTS_FILE": str(attempts),
                    "FAIL_ATTEMPTS": str(failures),
                    "FAIL_MESSAGE": message,
                    "ARGS_FILE": str(root / "args"),
                    "CHECKS": checks,
                },
            )
            args = root / "args"
            self.args = args.read_text().splitlines() if args.exists() else []
            return result, int(attempts.read_text())

    def test_checks_build_with_the_target(self):
        result, _ = self.run_build("", failures=0, checks="checks.x86_64-linux.a checks.x86_64-linux.b")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual(self.args[-3:], [".#test-target", ".#checks.x86_64-linux.a", ".#checks.x86_64-linux.b"])

    def test_no_checks_builds_only_the_target(self):
        result, attempts = self.run_build("", failures=0)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(attempts, 1)
        self.assertEqual(self.args[-1], ".#test-target")

    def test_an_aborted_script_fails_the_job(self):
        result, attempts = self.run_build("", failures=0, target=None)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(attempts, 0)

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


@unittest.skipUnless(Path("/bin/bash").exists(), "no /bin/bash")
class CiBuildSystemBashTest(CiBuildTest):
    """macOS runners and developer machines may run the script with Bash 3.2."""
    shell = "/bin/bash"


COMPARE_SCRIPT = SCRIPT.with_name("compare-with-base.sh")


class CompareWithBaseTest(unittest.TestCase):
    shell = "bash"

    def compare(self, head, base, base_revision="HEAD^1", base_fails=False):
        """Run the comparison in a two-commit repository; nix prints the given derivations."""
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            bin_dir = root / "bin"
            bin_dir.mkdir()
            nix = bin_dir / "nix"
            nix.write_text('''#!/usr/bin/env bash
printf '%s\n' "$@" >> "$ARGS_FILE"
case "$*" in
  *'&rev='*) [[ -z "$BASE_FAILS" ]] || exit 1; printf '%s\n' $BASE_DRVS ;;
  *) printf '%s\n' $HEAD_DRVS ;;
esac
''')
            nix.chmod(0o755)
            repository = root / "repository"
            repository.mkdir()
            git = ["git", "-C", str(repository), "-c", "user.name=CI", "-c", "user.email=ci@example.invalid"]
            subprocess.run(["git", "init", "-q", str(repository)], check=True)
            for message in ("base", "merge"):
                subprocess.run([*git, "commit", "-q", "--allow-empty", "-m", message], check=True)
            self.base = subprocess.run(
                [*git, "rev-parse", "HEAD^1"], check=True, capture_output=True, text=True,
            ).stdout.strip()
            output = root / "output"
            output.touch()
            result = subprocess.run(
                [self.shell, str(COMPARE_SCRIPT)], cwd=repository, capture_output=True, text=True,
                env={
                    **{key: value for key, value in os.environ.items() if key not in ("CHECKS", "BASE_REVISION")},
                    "PATH": str(bin_dir) + os.pathsep + os.environ["PATH"],
                    "TARGET": "test-target",
                    "CHECKS": 'checks.x86_64-linux."a"',
                    "BASE_REVISION": base_revision,
                    "HEAD_DRVS": head,
                    "BASE_DRVS": base,
                    "BASE_FAILS": "1" if base_fails else "",
                    "ARGS_FILE": str(root / "args"),
                    "GITHUB_OUTPUT": str(output),
                },
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            args = root / "args"
            self.args = args.read_text().splitlines() if args.exists() else []
            self.repository = repository
            return output.read_text()

    def test_matching_derivations_skip_the_build(self):
        self.assertEqual(self.compare("/a.drv /b.drv", "/b.drv /a.drv"), "changed=false\n")
        url = f"git+file://{self.repository.resolve()}?shallow=1&rev={self.base}"
        self.assertIn(f'{url}#checks.x86_64-linux."a"', self.args)
        self.assertIn(f"{url}#test-target", self.args)

    def test_changed_derivations_build(self):
        self.assertEqual(self.compare("/a.drv /b.drv", "/a.drv /c.drv"), "changed=true\n")

    def test_failed_base_evaluation_builds(self):
        self.assertEqual(self.compare("/a.drv", "/a.drv", base_fails=True), "changed=true\n")

    def test_without_a_base_builds_without_evaluating(self):
        self.assertEqual(self.compare("/a.drv", "/a.drv", base_revision=""), "changed=true\n")
        self.assertEqual(self.args, [])


@unittest.skipUnless(Path("/bin/bash").exists(), "no /bin/bash")
class CompareWithBaseSystemBashTest(CompareWithBaseTest):
    shell = "/bin/bash"


if __name__ == "__main__":
    unittest.main()
