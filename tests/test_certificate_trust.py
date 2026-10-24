"""The Apple bundle filter must preserve unrelated roots and local state."""

from pathlib import Path
import os
import stat
import subprocess
import tempfile
import unittest


def certificate(name):
    return (f"=== /C=XX/O=Test/CN={name}\n"
            f"-----BEGIN CERTIFICATE-----\n{name}\n-----END CERTIFICATE-----\n")


class AppleBundleFilter(unittest.TestCase):
    def test_scoped_removal_and_idempotent_backup(self):
        with tempfile.TemporaryDirectory() as directory:
            bundle = Path(directory) / "cert.pem"
            keep = certificate("emSign Root CA - G1") + certificate("AAA Certificate Services Extra")
            original = ("### First organization\n" + certificate("AAA Certificate Services")
                        + certificate("emSign ECC Root CA - G3") + keep
                        + "### Next organization\n" + certificate("Another Root"))
            expected = "### First organization\n" + keep + "### Next organization\n" + certificate("Another Root")
            bundle.write_text(original)
            bundle.chmod(0o640)
            subprocess.run(["filter-apple-ca-roots", str(bundle)], check=True)
            self.assertEqual(bundle.read_text(), expected)
            self.assertEqual(stat.S_IMODE(bundle.stat().st_mode), 0o640)
            backup = Path(str(bundle) + ".before-emudhra")
            self.assertEqual(backup.read_text(), original)
            first_stat = bundle.stat()
            subprocess.run(["filter-apple-ca-roots", str(bundle)], check=True)
            self.assertEqual(bundle.stat().st_ino, first_stat.st_ino)
            self.assertEqual(bundle.stat().st_mtime_ns, first_stat.st_mtime_ns)
            self.assertEqual(backup.read_text(), original)
            self.assertEqual(len(list(Path(directory).iterdir())), 2)

    def test_does_not_follow_symlinks_or_empty_the_trust_store(self):
        with tempfile.TemporaryDirectory() as directory:
            bundle = Path(directory) / "cert.pem"
            original = certificate("AAA Certificate Services")
            bundle.write_text(original)
            link = Path(directory) / "link.pem"
            link.symlink_to(bundle)
            for target in [link, bundle]:
                result = subprocess.run(["filter-apple-ca-roots", str(target)], capture_output=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(bundle.read_text(), original)
            self.assertEqual(len(list(Path(directory).iterdir())), 2)


class BuilderCompatibility(unittest.TestCase):
    def test_known_removed_roots_are_idempotent_but_unknown_names_fail(self):
        with tempfile.TemporaryDirectory() as directory:
            blocklist = Path(directory) / "blocklist.txt"
            output = Path(directory) / "bundle.pem"
            blocklist.write_text("emSign ECC Root CA - G3\nemSign Root CA - C1\n"
                                 "emSign ECC Root CA - C3\nComodo AAA Services root\n")
            command = ["buildcatrust", "--certdata_input", os.environ["NSS_CERTDATA"],
                       "--blocklist_input", str(blocklist), "--ca_bundle_output", str(output)]
            subprocess.run(command, check=True)
            self.assertIn("-----BEGIN CERTIFICATE-----", output.read_text())
            blocklist.write_text("Not an actual CA name\n")
            result = subprocess.run(command, capture_output=True, text=True)
            self.assertEqual(result.returncode, 3)
            self.assertIn("Not an actual CA name", result.stderr)


if __name__ == "__main__":
    unittest.main()
