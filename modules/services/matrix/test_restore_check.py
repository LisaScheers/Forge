import hashlib
import importlib.util
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("restore", os.environ["RESTORE_CHECK_SCRIPT"])
restore = importlib.util.module_from_spec(spec)
spec.loader.exec_module(restore)


class CheckpointTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.source = Path(self.temporary.name) / "checkpoint"
        self.source.mkdir()
        (self.source / "COMPLETE").write_text("complete\n")
        (self.source / "payload").write_bytes(b"database fixture")
        digest = hashlib.sha256(b"database fixture").hexdigest()
        (self.source / "SHA256SUMS").write_text(digest + "  ./payload\n")

    def test_valid_checkpoint(self):
        self.assertEqual(restore.verify_checkpoint(self.source), 1)

    def test_corruption_fails(self):
        (self.source / "payload").write_bytes(b"damaged")
        with self.assertRaisesRegex(RuntimeError, "checksum mismatch"):
            restore.verify_checkpoint(self.source)

    def test_incomplete_checkpoint_fails(self):
        (self.source / "COMPLETE").unlink()
        with self.assertRaisesRegex(RuntimeError, "completion marker"):
            restore.verify_checkpoint(self.source)

    def test_path_escape_fails(self):
        (self.source / "SHA256SUMS").write_text("0" * 64 + "  ../outside\n")
        with self.assertRaisesRegex(RuntimeError, "escapes checkpoint"):
            restore.verify_checkpoint(self.source)

    def test_external_network_fails_closed(self):
        with patch.object(Path, "read_text", return_value="header\nheader\n lo: 0\n eth0: 0\n"):
            with self.assertRaisesRegex(RuntimeError, "private network"):
                restore.require_isolated_network()


if __name__ == "__main__":
    unittest.main()
