"""Check just features argument handling with a stand-in nix."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


JUSTFILE = Path(__file__).resolve().parents[1] / "Justfile"


class FeaturesTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        shutil.copy(JUSTFILE, self.root / "Justfile")
        self.log = self.root / "nix-calls"
        nix = self.root / "nix"
        nix.write_text('''#!/usr/bin/env bash
printf '%s\\n' "$@" >> "$FEATURES_TEST_LOG"
printf '%s' "$FEATURES_TEST_OUTPUT"
''')
        nix.chmod(0o755)

    def features(self, *args, output=""):
        return subprocess.run(
            ["just", "--justfile", str(self.root / "Justfile"), "features", *args],
            env=dict(os.environ, PATH=f"{self.root}:{os.environ['PATH']}",
                     FEATURES_TEST_LOG=str(self.log), FEATURES_TEST_OUTPUT=output),
            text=True, capture_output=True, timeout=10,
        )

    def test_lists_the_files_nix_returns(self):
        result = self.features("nook", output="modules/hosts/nook/default.nix")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "modules/hosts/nook/default.nix\n")
        self.assertIn('(lookup "nixos" "nook")', self.log.read_text())

    def test_unknown_profile_fails(self):
        result = self.features("no-such-profile")
        self.assertEqual(result.returncode, 1)
        self.assertIn("No file binds nixos.no-such-profile.", result.stderr)

    def test_rejects_an_unknown_class_without_evaluating(self):
        for args in (("nook", "network"), ("nook", "bogus"), ('x"', "nixos"), ("", "home")):
            with self.subTest(args=args):
                result = self.features(*args)
                self.assertEqual(result.returncode, 2, result.stderr)
                self.assertIn("Expected a profile name and nixos, darwin or home.", result.stderr)
        self.assertFalse(self.log.exists())


if __name__ == "__main__":
    unittest.main()
