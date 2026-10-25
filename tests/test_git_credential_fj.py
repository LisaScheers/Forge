"""Check the fj credential adapter using isolated logins and no real tokens."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "modules/shell/git-credential-fj.sh"


class FjCredentialTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.keys = self.root / (
            "Library/Application Support/forgejo-cli.forgejo-cli/keys.json"
            if sys.platform == "darwin" else "data/forgejo-cli/keys.json"
        )
        self.keys.parent.mkdir(parents=True)
        self.keys.write_text(json.dumps({"hosts": {
            "git.bylisa.dev": {"type": "OAuth", "token": "old-token"},
            "other.example": {"type": "Application", "token": "other-token"},
        }}))
        self.log = self.root / "fj-calls"
        fj = self.root / "fj"
        fj.write_text('''#!/usr/bin/env bash
set -euo pipefail
printf '%s\\n' "$@" >> "$FJ_TEST_LOG"
if [[ "${FJ_TEST_FAIL:-0}" == 1 ]]; then exit 42; fi
printf '%s' '{"hosts":{"git.bylisa.dev":{"type":"OAuth","token":"fresh-token"}}}' > "$FJ_TEST_KEYS"
''')
        fj.chmod(0o755)
        self.env = dict(os.environ, PATH=f"{self.root}:{os.environ['PATH']}",
                        HOME=str(self.root), XDG_DATA_HOME=str(self.root / "data"),
                        FJ_TEST_LOG=str(self.log), FJ_TEST_KEYS=str(self.keys))

    def run_helper(self, operation="get", protocol="https", host="git.bylisa.dev"):
        return subprocess.run(
            ["bash", "-euo", "pipefail", str(SCRIPT), operation],
            input=f"protocol={protocol}\nhost={host}\nusername=Lisa\n\n",
            env=self.env, text=True, capture_output=True, timeout=10,
        )

    def test_uses_fj_and_reads_token_after_refresh(self):
        result = self.run_helper()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "username=Lisa\npassword=fresh-token\n\n")
        self.assertEqual(self.log.read_text().splitlines(),
                         ["--host", "https://git.bylisa.dev", "whoami"])

    def test_unrelated_hosts_and_insecure_protocols_never_access_fj(self):
        for protocol, host in (("https", "other.example"),
                               ("https", "git.bylisa.dev.evil.example"),
                               ("http", "git.bylisa.dev")):
            with self.subTest(protocol=protocol, host=host):
                result = self.run_helper(protocol=protocol, host=host)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout, "")
                self.assertFalse(self.log.exists())

    def test_store_and_erase_do_not_change_fj_login(self):
        original = self.keys.read_bytes()
        for operation in ("store", "erase"):
            with self.subTest(operation=operation):
                result = self.run_helper(operation)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout, "")
                self.assertEqual(self.keys.read_bytes(), original)
                self.assertFalse(self.log.exists())

    def test_fj_failure_does_not_return_stale_credentials(self):
        self.env["FJ_TEST_FAIL"] = "1"
        result = self.run_helper()
        self.assertEqual(result.returncode, 42)
        self.assertEqual(result.stdout, "")


if __name__ == "__main__":
    unittest.main()
