import hashlib
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import tempfile
import shutil
import types
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

    def test_history_verification_can_be_explicitly_disabled_without_proofs(self):
        (self.source / "history-verification-policy.json").write_text('{"version":1,"enabled":false}')
        with patch.object(restore, "verify_history", side_effect=AssertionError("History must remain optional")):
            self.assertEqual(restore.verify_optional_history("http://restore.test", self.source),
                             {"verified_rooms": 0, "history_verification_enabled": False})
            (self.source / "history-verification-policy.json").unlink()
            self.assertEqual(restore.verify_optional_history("http://restore.test", self.source)["verified_rooms"], 0)

    def test_disabled_history_rejects_stale_migration_proofs(self):
        self.history_fixture()
        (self.source / "history-verification-policy.json").write_text('{"version":1,"enabled":false}')
        with self.assertRaisesRegex(RuntimeError, "stale proofs"):
            restore.verify_optional_history("http://restore.test", self.source)

    def test_explicit_generic_history_retains_full_room_and_media_checks(self):
        opener, _, _, _, _ = self.history_fixture(old_available=True)
        (self.source / "verification/sec-hive-pilot.json").rename(self.source / "verification/history-account.json")
        (self.source / "history-verification-policy.json").write_text('{"version":1,"enabled":true}')
        with patch.object(restore, "build_opener", return_value=opener):
            result = restore.verify_optional_history("http://restore.test", self.source)
        self.assertEqual(result["verified_rooms"], 1)
        self.assertEqual(result["attachments_downloaded"], 2)
        self.assertTrue(result["thumbnail_regenerated_from_original"])

    def test_legacy_complete_proofs_remain_verifiable(self):
        opener, _, _, _, _ = self.history_fixture(old_available=True)
        with patch.object(restore, "build_opener", return_value=opener):
            self.assertEqual(restore.verify_optional_history("http://restore.test", self.source)["verified_rooms"], 1)

    def test_incomplete_or_invalid_history_policy_cannot_silently_skip_checks(self):
        verification = self.source / "verification"
        verification.mkdir(); (verification / "history-manifest.json").write_text("{}")
        with self.assertRaisesRegex(RuntimeError, "incomplete"):
            restore.verify_optional_history("http://restore.test", self.source)
        policy = self.source / "history-verification-policy.json"
        policy.write_text('{"version":1,"enabled":true}')
        with self.assertRaisesRegex(RuntimeError, "incomplete"):
            restore.verify_optional_history("http://restore.test", self.source)
        policy.write_text('{"version":1,"enabled":"false"}')
        with self.assertRaisesRegex(RuntimeError, "Unsupported"):
            restore.verify_optional_history("http://restore.test", self.source)

    def generic_restore_fixture(self):
        synapse = self.source / "synapse"
        media = synapse / "media_store/local_content/ab/cd/original"
        media.parent.mkdir(parents=True); media.write_bytes(b"original fixture image")
        (synapse / "homeserver.signing.key").write_bytes(b"isolated signing key")
        bridge = self.source / "bridge"
        bridge.mkdir()
        registration = {"as_token": "isolated-as-token", "hs_token": "isolated-hs-token"}
        (bridge / "discord-registration.yaml").write_text(json.dumps(registration))
        bridge_config = {"homeserver": {}, "appservice": {**registration, "database": {}},
                         "bridge": {"provisioning": {}}}
        (bridge / "config.yaml").write_text(json.dumps(bridge_config))
        (self.source / "synapse-config.json").write_text('{"server_name":"restore.test"}')
        for name in ["synapse.dump", "bridge.dump"]:
            (self.source / name).write_bytes(b"isolated database dump")
        (self.source / "bridge-counts.json").write_text('{"portals":0,"messages":0,"threads":0,"users":0}')
        (self.source / "plural-enabled").write_text("0\n")
        runtime = self.source / "runtime"
        runtime.mkdir()
        for name in ["matrix-registration-secret", "matrix-turn-secret"]:
            (runtime / name).write_bytes(b"isolated runtime secret")
        (self.source / "history-verification-policy.json").write_text('{"version":1,"enabled":false}')
        self.write_media_policy()
        self.reseal()

    def reseal(self):
        lines = []
        for filename in sorted(self.source.rglob("*")):
            if filename.is_file() and filename.name not in {"COMPLETE", "SHA256SUMS"}:
                lines.append(hashlib.sha256(filename.read_bytes()).hexdigest() + "  ./" + filename.relative_to(self.source).as_posix())
        (self.source / "SHA256SUMS").write_text("\n".join(lines) + "\n")

    def test_generic_copy_checks_signing_key_and_every_media_file(self):
        self.generic_restore_fixture()
        copied = Path(self.temporary.name) / "copied-synapse"
        shutil.copytree(self.source / "synapse", copied)
        self.assertEqual(restore.verify_synapse_copy(self.source, copied), {"signing_key_preserved": True, "media_files_checked": 1})
        key = copied / "homeserver.signing.key"; key.write_bytes(b"changed key")
        with self.assertRaisesRegex(RuntimeError, "checksum differs"):
            restore.verify_synapse_copy(self.source, copied)
        key.write_bytes((self.source / "synapse/homeserver.signing.key").read_bytes())
        (copied / "media_store/unlisted").write_bytes(b"unexpected")
        with self.assertRaisesRegex(RuntimeError, "file set differs"):
            restore.verify_synapse_copy(self.source, copied)

    def run_generic_main(self, counts=None):
        self.reseal()
        directory = Path(self.temporary.name) / "main"
        directory.mkdir(); shutil.copytree(self.source, directory / "input")
        commands, starts, requests = [], [], []
        class Process:
            def terminate(self): pass
            def wait(self, timeout=30): return 0
        def run(command, **kwargs):
            commands.append(command)
            output = counts or {"portals": 0, "messages": 0, "threads": 0, "users": 0}
            return types.SimpleNamespace(stdout=json.dumps(output).encode())
        def start(command, **kwargs):
            starts.append(command[0]); return Process()
        class Opener:
            def open(self, url, timeout=5):
                requests.append(url)
                return contextlib.nullcontext(types.SimpleNamespace(status=200))
        previous = Path.cwd()
        try:
            os.chdir(directory)
            with patch.object(restore, "require_isolated_network"), patch.object(restore.subprocess, "run", side_effect=run), \
                 patch.object(restore.subprocess, "Popen", side_effect=start), patch.object(restore, "build_opener", return_value=Opener()), \
                 patch.object(restore, "verify_history", side_effect=AssertionError("No pilot proof should be needed")), contextlib.redirect_stdout(io.StringIO()):
                restore.main()
            result = json.loads((directory / "work/result.json").read_text())
            return result, commands, starts, requests
        finally:
            os.chdir(previous)

    def test_main_without_pilot_still_restores_databases_media_keys_and_services(self):
        self.generic_restore_fixture()
        result, commands, starts, requests = self.run_generic_main()
        self.assertEqual(result["verified_rooms"], 0)
        self.assertTrue(result["bridge_counts_match"] and result["application_service_tokens_match"] and result["signing_key_preserved"])
        self.assertEqual(result["media_files_checked"], 1)
        self.assertEqual(sum(command[0] == "pg_restore" for command in commands), 2)
        self.assertEqual(starts, ["synapse_homeserver", "mautrix-discord"])
        self.assertEqual(len(requests), 2)

    def test_no_pilot_does_not_bypass_database_count_mismatch(self):
        self.generic_restore_fixture()
        with self.assertRaisesRegex(RuntimeError, "bridge mappings differ"):
            self.run_generic_main({"portals": 99})

    def test_no_pilot_does_not_bypass_missing_signing_key(self):
        self.generic_restore_fixture()
        (self.source / "synapse/homeserver.signing.key").unlink()
        with self.assertRaisesRegex(RuntimeError, "no signing key"):
            self.run_generic_main()

    def test_no_pilot_does_not_bypass_application_service_token_mismatch(self):
        self.generic_restore_fixture()
        filename = self.source / "bridge/config.yaml"
        bridge = json.loads(filename.read_text()); bridge["appservice"]["as_token"] = "mismatched-isolated-token"
        filename.write_text(json.dumps(bridge))
        with self.assertRaisesRegex(RuntimeError, "tokens do not match"):
            self.run_generic_main()


if __name__ == "__main__":
    unittest.main()
