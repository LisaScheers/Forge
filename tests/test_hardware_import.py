"""Exercise hardware regeneration without connecting to or installing a host."""
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "scripts/import-hardware-config.sh"


class HardwareImportTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        subprocess.run(["git", "init", "--quiet", str(self.root)], check=True)
        self.target = self.root / "flake-parts/hosts/nook/hardware-configuration.nix"
        self.target.parent.mkdir(parents=True)
        self.target.write_text("{ forge.modules.nixos.nook = {}; }\n")
        self.source = self.root / "generated.nix"

    def run_import(self, host="nook"):
        return subprocess.run(
            ["bash", str(SCRIPT), host, str(self.source)],
            cwd=self.root, capture_output=True, text=True,
        )

    def test_generated_hardware_is_a_top_level_feature(self):
        self.source.write_text('{...}: { networking.hostName = "fixture"; }\n')
        result = self.run_import()
        self.assertEqual(result.returncode, 0, result.stderr)
        value = subprocess.check_output([
            "nix-instantiate", "--eval", "--strict", "--json", "--expr",
            f'((import {self.target} {{}}).forge.modules.nixos.nook {{}}).networking.hostName',
        ], text=True)
        self.assertEqual(value.strip(), '"fixture"')
        self.assertEqual(list(self.target.parent.glob("*.nix.*")), [])

    def test_invalid_generated_nix_preserves_existing_feature(self):
        before = self.target.read_text()
        self.source.write_text("{ broken = ; }")
        self.assertNotEqual(self.run_import().returncode, 0)
        self.assertEqual(self.target.read_text(), before)

    def test_host_name_cannot_escape_the_host_directory(self):
        before = self.target.read_text()
        self.source.write_text("{}")
        self.assertNotEqual(self.run_import("../nook").returncode, 0)
        self.assertEqual(self.target.read_text(), before)

    def test_unknown_host_is_not_created(self):
        self.source.write_text("{}")
        self.assertNotEqual(self.run_import("new-host").returncode, 0)
        self.assertFalse((self.root / "flake-parts/hosts/new-host").exists())


if __name__ == "__main__":
    unittest.main()
