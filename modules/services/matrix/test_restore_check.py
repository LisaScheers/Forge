import hashlib
import importlib.util
import json
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

    def write_media_policy(self):
        policy = {"version": 1,
                  "omitted_generated_media_directories": ["local_thumbnails", "remote_thumbnail", "url_cache_thumbnails"],
                  "original_media": "preserved", "thumbnail_database_metadata": "preserved"}
        (self.source / "media-backup-policy.json").write_text(json.dumps(policy))
        return policy

    def test_older_complete_media_checkpoint_is_supported(self):
        self.assertFalse(restore.thumbnail_cache_omitted(self.source))

    def test_generated_cache_omission_policy_is_supported(self):
        self.write_media_policy()
        self.assertTrue(restore.thumbnail_cache_omitted(self.source))

    def test_policy_cannot_omit_originals(self):
        policy = self.write_media_policy()
        policy["omitted_generated_media_directories"].append("local_content")
        (self.source / "media-backup-policy.json").write_text(json.dumps(policy))
        with self.assertRaisesRegex(RuntimeError, "Unsupported media backup policy"):
            restore.thumbnail_cache_omitted(self.source)

    def test_policy_must_match_actual_checkpoint(self):
        self.write_media_policy()
        directory = self.source / "synapse/media_store/local_thumbnails"
        directory.mkdir(parents=True)
        (directory / "unexpected").write_bytes(b"thumbnail")
        with self.assertRaisesRegex(RuntimeError, "contains omitted thumbnail cache"):
            restore.thumbnail_cache_omitted(self.source)


if __name__ == "__main__":
    unittest.main()
