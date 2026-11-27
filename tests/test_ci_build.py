"""Check CI download recovery and failure propagation without real builds."""
import json
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
CHECK = 'checks.x86_64-linux."a"'


class CompareWithBaseTest(unittest.TestCase):
    shell = "bash"

    def compare(self, head="/a.drv", base="/a.drv", checks=CHECK, base_revision="HEAD^1",
                base_runner="runner", fails="", harness_change=False):
        """Run the comparison on a merge commit whose first parent is the base.

        nix prints the given head and base derivations, the base matrix lists the
        job on base_runner, and fails names the evaluations (head, base, matrix)
        that fail.
        """
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            bin_dir = root / "bin"
            bin_dir.mkdir()
            nix = bin_dir / "nix"
            nix.write_text('''#!/usr/bin/env bash
printf '%s\n' "$@" >> "$ARGS_FILE"
case "$*" in
  eval*) [[ "$FAILS" != *matrix* ]] || exit 1; printf '%s\n' "$BASE_MATRIX" ;;
  *'&rev='*) [[ "$FAILS" != *base* ]] || exit 1; printf '%s\n' $BASE_DRVS ;;
  *) [[ "$FAILS" != *head* ]] || exit 1; printf '%s\n' $HEAD_DRVS ;;
esac
''')
            nix.chmod(0o755)
            repository = root / "repository"
            git = ["git", "-C", str(repository), "-c", "user.name=CI", "-c", "user.email=ci@example.invalid"]
            subprocess.run(["git", "init", "-q", str(repository)], check=True)
            subprocess.run([*git, "commit", "-q", "--allow-empty", "-m", "base"], check=True)
            if harness_change:
                (repository / ".github").mkdir()
                (repository / ".github/workflow.yml").write_text("changed\n")
                subprocess.run([*git, "add", "."], check=True)
            subprocess.run([*git, "commit", "-q", "--allow-empty", "-m", "merge"], check=True)
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
                    "CHECKS": checks,
                    "RUNNER": "runner",
                    "BASE_REVISION": base_revision,
                    "BASE_MATRIX": json.dumps([{"target": "test-target", "checks": checks, "runner": base_runner}]),
                    "HEAD_DRVS": head,
                    "BASE_DRVS": base,
                    "FAILS": fails,
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
        self.assertIn(f"{url}#{CHECK}", self.args)
        self.assertIn(f"{url}#test-target", self.args)
        self.assertIn(f"{url}#ciMatrix.include", self.args)

    def test_a_job_without_checks_can_skip(self):
        self.assertEqual(self.compare(checks=""), "changed=false\n")

    def test_changed_derivations_build(self):
        self.assertEqual(self.compare("/a.drv /b.drv", "/a.drv /c.drv"), "changed=true\n")

    def test_empty_derivation_lists_build(self):
        self.assertEqual(self.compare("", ""), "changed=true\n")

    def test_failed_evaluations_build(self):
        for side in ("head", "base", "matrix"):
            with self.subTest(side=side):
                self.assertEqual(self.compare(fails=side), "changed=true\n")

    def test_a_job_new_to_the_base_matrix_or_its_runner_builds(self):
        self.assertEqual(self.compare(base_runner="other-runner"), "changed=true\n")

    def test_build_workflow_changes_build_without_evaluating(self):
        self.assertEqual(self.compare(harness_change=True), "changed=true\n")
        self.assertEqual(self.args, [])

    def test_without_a_resolvable_base_builds_without_evaluating(self):
        for revision in ("", "HEAD^5"):
            with self.subTest(revision=revision):
                self.assertEqual(self.compare(base_revision=revision), "changed=true\n")
                self.assertEqual(self.args, [])


@unittest.skipUnless(Path("/bin/bash").exists(), "no /bin/bash")
class CompareWithBaseSystemBashTest(CompareWithBaseTest):
    shell = "/bin/bash"


if __name__ == "__main__":
    unittest.main()
