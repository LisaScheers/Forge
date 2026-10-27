import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from urllib.error import HTTPError
from urllib.request import Request

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

    def test_unlisted_stale_media_fails(self):
        directory = self.source / "synapse/media_store/local_content/ab/cd"
        directory.mkdir(parents=True)
        (directory / "stale-original").write_bytes(b"old payload")
        with self.assertRaisesRegex(RuntimeError, "file set differs"):
            restore.verify_checkpoint(self.source)

    def test_missing_listed_file_fails(self):
        (self.source / "payload").unlink()
        with self.assertRaisesRegex(RuntimeError, "file set differs"):
            restore.verify_checkpoint(self.source)

    def test_duplicate_normalized_paths_fail(self):
        line = (self.source / "SHA256SUMS").read_text()
        (self.source / "SHA256SUMS").write_text(line + line.replace("./payload", "payload"))
        with self.assertRaisesRegex(RuntimeError, "duplicate paths"):
            restore.verify_checkpoint(self.source)

    def test_absolute_path_inside_checkpoint_is_rejected(self):
        digest = hashlib.sha256(b"database fixture").hexdigest()
        (self.source / "SHA256SUMS").write_text(digest + "  " + str(self.source / "payload") + "\n")
        with self.assertRaisesRegex(RuntimeError, "escapes checkpoint"):
            restore.verify_checkpoint(self.source)

    def test_symlink_file_fails(self):
        (self.source / "alias").symlink_to(self.source / "payload")
        with self.assertRaisesRegex(RuntimeError, "nonregular file"):
            restore.verify_checkpoint(self.source)

    def test_symlink_directory_fails(self):
        (self.source / "alias-directory").symlink_to(self.source, target_is_directory=True)
        with self.assertRaisesRegex(RuntimeError, "nonregular directory"):
            restore.verify_checkpoint(self.source)

    def test_fifo_fails_without_opening_it(self):
        os.mkfifo(self.source / "pipe")
        with self.assertRaisesRegex(RuntimeError, "nonregular file"):
            restore.verify_checkpoint(self.source)

    def test_invalid_digest_fails(self):
        (self.source / "SHA256SUMS").write_text("invalid  ./payload\n")
        with self.assertRaisesRegex(RuntimeError, "digest is invalid"):
            restore.verify_checkpoint(self.source)

    def test_markers_are_only_permitted_unlisted_files(self):
        (self.source / "extra-marker").write_text("not allowed")
        with self.assertRaisesRegex(RuntimeError, "file set differs"):
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

    def history_fixture(self, old_available=False):
        verification = self.source / "verification"
        verification.mkdir()
        (verification / "sec-hive-pilot.json").write_text(json.dumps({"access_token": "isolated-test-token"}))
        payloads = {"old": b"old-image", "new": b"new-image"}
        events = [{"event_id": "$new", "origin_server_ts": 2, "sender": "@new:test",
                   "content": {"url": "mxc://bylisa.dev/new", "info": {"mimetype": "image/png"},
                               "m.relates_to": {"m.in_reply_to": {"event_id": "$old"}}}},
                  {"event_id": "$old", "origin_server_ts": 1, "sender": "@old:test",
                   "content": {"url": "mxc://bylisa.dev/old", "info": {"mimetype": "image/png"}}}]
        attachments = [{"event_id": "$" + name, "bytes": len(payload), "sha256": hashlib.sha256(payload).hexdigest()}
                       for name, payload in payloads.items()]
        manifest = {"room_id": "!room:test", "parts": [{"event_id": event["event_id"],
                    "timestamp": event["origin_server_ts"], "sender": event["sender"]} for event in events],
                    "attachments": attachments, "replies": [{"event_id": "$new", "reference": {"messageId": "old"}}],
                    "primary_events": {"old": "$old"}}
        (verification / "history-manifest.json").write_text(json.dumps(manifest))
        self.write_media_policy()
        requests = []

        class Opener:
            def open(self, request, timeout=45):
                url = request.full_url
                requests.append(url)
                if "/messages?" in url:
                    return io.BytesIO(json.dumps({"chunk": events}).encode())
                if "/thumbnail/" in url:
                    return io.BytesIO(b"generated-thumbnail")
                name = url.rsplit("/", 1)[-1]
                if name == "old" and not old_available:
                    raise HTTPError(url, 404, "Not found", {}, io.BytesIO(b"{}"))
                return io.BytesIO(payloads[name])

        opener = Opener()
        archived = self.source / "archived-old-image"
        archived.write_bytes(payloads["old"])

        def validated(mxc, expected_bytes, expected_sha256):
            if mxc != "mxc://bylisa.dev/old":
                return False
            actual = archived.read_bytes()
            if len(actual) != expected_bytes or hashlib.sha256(actual).hexdigest() != expected_sha256:
                raise RuntimeError("Validated archive differs")
            try:
                opener.open(Request("http://restore.test/_matrix/client/v1/media/download/" + mxc.removeprefix("mxc://")))
            except HTTPError as error:
                if error.code != 404:
                    raise
                error.close()
                return True
            raise RuntimeError("Expected authenticated media 404")

        return opener, validated, requests, events, archived

    def test_default_history_still_requires_each_download(self):
        opener, _, _, _, _ = self.history_fixture()
        with patch.object(restore, "build_opener", return_value=opener), self.assertRaises(HTTPError) as failure:
            restore.verify_history("http://restore.test", self.source)
        failure.exception.close()

    def test_default_history_retains_normal_media_and_thumbnail_checks(self):
        opener, _, requests, _, _ = self.history_fixture(old_available=True)
        with patch.object(restore, "build_opener", return_value=opener):
            result = restore.verify_history("http://restore.test", self.source)
        self.assertEqual(result["attachments_downloaded"], 2)
        self.assertEqual(result["attachments_archived_by_policy"], 0)
        self.assertTrue(result["thumbnail_regenerated_from_original"])
        self.assertTrue(any("/thumbnail/bylisa.dev/old?" in url for url in requests))

    def test_validated_omission_rechecks_bytes_and_404_then_uses_retained_thumbnail(self):
        opener, validated, requests, _, _ = self.history_fixture()
        with patch.object(restore, "build_opener", return_value=opener):
            result = restore.verify_history("http://restore.test", self.source, validated)
        self.assertEqual(result["attachments_downloaded"], 1)
        self.assertEqual(result["attachments_archived_by_policy"], 1)
        self.assertTrue(any("/thumbnail/bylisa.dev/new?" in url for url in requests))
        self.assertFalse(any("/thumbnail/bylisa.dev/old?" in url for url in requests))

    def test_changed_archived_bytes_fail(self):
        opener, validated, _, _, archived = self.history_fixture()
        archived.write_bytes(b"corrupt archive")
        with patch.object(restore, "build_opener", return_value=opener), self.assertRaisesRegex(RuntimeError, "Validated archive differs"):
            restore.verify_history("http://restore.test", self.source, validated)

    def test_callback_cannot_broadly_accept_truthy_nonboolean(self):
        opener, _, _, _, _ = self.history_fixture()
        with patch.object(restore, "build_opener", return_value=opener), self.assertRaises(HTTPError) as failure:
            restore.verify_history("http://restore.test", self.source, lambda *arguments: 1)
        failure.exception.close()

    def test_thumbnail_check_requires_a_retained_image(self):
        opener, _, _, _, _ = self.history_fixture()
        with patch.object(restore, "build_opener", return_value=opener), self.assertRaisesRegex(RuntimeError, "no retained image"):
            restore.verify_history("http://restore.test", self.source, lambda *arguments: True)

    def test_archive_callback_preserves_author_timestamp_and_reply_checks(self):
        opener, validated, _, events, _ = self.history_fixture()
        events[0]["origin_server_ts"] = 99
        with patch.object(restore, "build_opener", return_value=opener), self.assertRaisesRegex(RuntimeError, "author/timestamp mismatch"):
            restore.verify_history("http://restore.test", self.source, validated)
        events[0]["origin_server_ts"] = 2
        events[0]["content"]["m.relates_to"]["m.in_reply_to"]["event_id"] = "$wrong"
        with patch.object(restore, "build_opener", return_value=opener), self.assertRaisesRegex(RuntimeError, "reply relation mismatch"):
            restore.verify_history("http://restore.test", self.source, validated)


if __name__ == "__main__":
    unittest.main()
