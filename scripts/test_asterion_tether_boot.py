"""Exercise payload checks without opening a target serial connection."""

import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


LOADER = Path(os.environ.get("ASTERION_TETHER_LOADER", Path(__file__).with_name("asterion-tether-boot.py")))
REVISION = "f5a82fdb6264edd2fb0c02e2d0f750bf33380854"


class PayloadChecks(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.payload = Path(self.directory.name)
        for name in ("Image.gz", "t6030-j516s.dtb", "initrd.gz", "m1n1.bin", "bootargs"):
            (self.payload / name).write_bytes(name.encode())
        (self.payload / "manifest.json").write_text(json.dumps({
            "kind": "asterion-gpu-test",
            "target": "J516s",
            "m1n1Revision": REVISION,
        }))
        self.checksums()

    def checksums(self):
        (self.payload / "SHA256SUMS").write_text("".join(
            f"{hashlib.sha256(item.read_bytes()).hexdigest()}  {item.name}\n"
            for item in sorted(self.payload.iterdir()) if item.name != "SHA256SUMS"
        ))

    def run_loader(self, *arguments, revision=REVISION):
        # No proxy source/dependencies: a successful --check must remain offline.
        environment = dict(os.environ)
        if revision is None:
            environment.pop("M1N1_SOURCE_REV", None)
        else:
            environment["M1N1_SOURCE_REV"] = revision
        environment.pop("M1N1_SOURCE", None)
        return subprocess.run(
            [sys.executable, "-B", str(LOADER), str(self.payload), *arguments],
            env=environment, text=True, capture_output=True, check=False,
        )

    def test_complete_payload_checks_offline(self):
        result = self.run_loader("--check")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("no target connection", result.stdout)

    def test_baseline_payload_still_checks_without_gpu_shell(self):
        (self.payload / "manifest.json").unlink()
        (self.payload / "SHA256SUMS").unlink()
        result = self.run_loader("--check", revision=None)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_corruption_is_refused(self):
        (self.payload / "Image.gz").write_bytes(b"changed kernel")
        result = self.run_loader("--check")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("checksum mismatch: Image.gz", result.stderr)

    def test_missing_manifest_cannot_downgrade_to_baseline(self):
        (self.payload / "manifest.json").unlink()
        result = self.run_loader("--check")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("missing manifest.json", result.stderr)

    def test_wrong_proxy_revision_is_refused(self):
        result = self.run_loader("--check", revision="other")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("matching nix develop", result.stderr)

    def test_incomplete_checksums_are_refused(self):
        manifest = self.payload / "SHA256SUMS"
        manifest.write_text("\n".join(manifest.read_text().splitlines()[1:]) + "\n")
        result = self.run_loader("--check")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Incomplete payload", result.stderr)

    def test_boot_requires_terminal_before_proxy_import(self):
        result = self.run_loader("--device", "/dev/not-a-device", "--esp-uuid", "6b247b53-374b-4729-ba44-9b93de5aba90")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("requires a PTY", result.stderr)


if __name__ == "__main__":
    unittest.main()
