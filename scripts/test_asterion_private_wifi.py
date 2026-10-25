"""Validate the private CPIO overlay using a dummy credential."""

import gzip
import base64
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import stat
import tempfile
import unittest


spec = importlib.util.spec_from_file_location("private_wifi", os.environ.get("ASTERION_PRIVATE_WIFI", Path(__file__).with_name("asterion-private-wifi.py")))
wifi = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wifi)


class PrivateWifiTests(unittest.TestCase):
    def test_optional_file_key_overlay(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory) / "base"
            base.mkdir()
            for name in wifi.FILES:
                (base / name).write_bytes(b"base-file")
            (base / "manifest.json").write_text(json.dumps({
                "kind": "asterion-gpu-test", "target": "J516s",
                "privateWifiSupport": True, "privateSshSupport": True,
            }))
            original = gzip.compress(b"base archive", mtime=0)
            (base / "initrd.gz").write_bytes(original)
            public_key = "ssh-ed25519 " + base64.b64encode(b"\0\0\0\x0bssh-ed25519\0\0\0\x20" + bytes(32)).decode() + " test\n"
            output = Path(directory) / "private"
            wifi.create_payload(base, output, "dummy-test-password", public_key)
            archive = gzip.decompress((output / "initrd.gz").read_bytes()[len(original):])
            self.assertIn(b"asterion-test-authorized-key\0", archive)
            self.assertIn(public_key.encode(), archive)
            self.assertTrue(json.loads((output / "manifest.json").read_text())["privateSsh"])
            with self.assertRaises(ValueError):
                wifi.create_payload(base, Path(directory) / "invalid", "dummy-test-password", public_key + public_key)
            self.assertFalse((Path(directory) / "invalid").exists())
            with self.assertRaises(ValueError):
                wifi.create_payload(base, Path(directory) / "invalid", "dummy-test-password", "ssh-ed25519 YWJj\n")
            manifest = json.loads((base / "manifest.json").read_text())
            del manifest["privateSshSupport"]
            (base / "manifest.json").write_text(json.dumps(manifest))
            with self.assertRaisesRegex(ValueError, "SSH bootstrap"):
                wifi.create_payload(base, Path(directory) / "unsupported", "dummy-test-password", public_key)
            self.assertFalse((Path(directory) / "unsupported").exists())

    def test_private_overlay_permissions_contents_and_checksums(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory) / "base"
            base.mkdir()
            for name in wifi.FILES:
                (base / name).write_bytes(b"base-file")
            (base / "manifest.json").write_text(json.dumps({
                "kind": "asterion-gpu-test", "target": "J516s", "privateWifiSupport": True,
            }))
            original = gzip.compress(b"base archive", mtime=0)
            (base / "initrd.gz").write_bytes(original)
            output = Path(directory) / "private"
            password = "dummy-test-password"
            wifi.create_payload(base, output, password)
            self.assertEqual(stat.S_IMODE(output.stat().st_mode), 0o700)
            for name in (*wifi.FILES, "SHA256SUMS"):
                self.assertEqual(stat.S_IMODE((output / name).stat().st_mode), 0o600)
            initrd = (output / "initrd.gz").read_bytes()
            self.assertTrue(initrd.startswith(original))
            archive = gzip.decompress(initrd[len(original):])
            self.assertNotIn(password.encode(), archive)
            psk = hashlib.pbkdf2_hmac("sha1", password.encode(), wifi.SSID.encode(), 4096, 32).hex().encode()
            self.assertEqual(archive.count(psk), 2)
            offset = 0
            names = []
            while archive[offset:offset + 6] == b"070701":
                values = [int(archive[offset + 6 + index * 8:offset + 14 + index * 8], 16) for index in range(13)]
                name_start = offset + 110
                name = archive[name_start:name_start + values[11] - 1].decode()
                offset = (name_start + values[11] + 3) & ~3
                offset = (offset + values[6] + 3) & ~3
                names.append(name)
                if name != "TRAILER!!!":
                    self.assertEqual(values[1:4], [0o100600, 0, 0])
            self.assertEqual(names, ["asterion-wifi.nmconnection", "asterion-wifi.psk", "TRAILER!!!"])
            for line in (output / "SHA256SUMS").read_text().splitlines():
                digest, name = line.split("  ", 1)
                self.assertEqual(hashlib.sha256((output / name).read_bytes()).hexdigest(), digest)
            with self.assertRaises(FileExistsError):
                wifi.create_payload(base, output, password)

    def test_old_image_is_rejected_before_writing(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            (base / "manifest.json").write_text('{"kind":"asterion-gpu-test","target":"J516s"}')
            with self.assertRaisesRegex(ValueError, "bootstrap"):
                wifi.create_payload(base, base / "private", "dummy-test-password")
            self.assertFalse((base / "private").exists())


if __name__ == "__main__":
    unittest.main()
