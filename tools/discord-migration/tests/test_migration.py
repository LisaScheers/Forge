import contextlib
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from discord_migration import ADMINISTRATOR, CONNECT, READ_MESSAGE_HISTORY, VIEW_CHANNEL, can_read_history, permissions_for, verify_archive


class PermissionTests(unittest.TestCase):
    def test_voice_chat_needs_connect_even_when_text_history_is_allowed(self):
        permissions = VIEW_CHANNEL | READ_MESSAGE_HISTORY
        self.assertTrue(can_read_history({"type": 0}, permissions))
        for channel_type in (2, 13):
            self.assertFalse(can_read_history({"type": channel_type}, permissions))
            self.assertTrue(can_read_history({"type": channel_type}, permissions | CONNECT))

    def test_administrator_has_implicit_voice_history_access(self):
        channel = {"type": 2, "permission_overwrites": [{"id": "guild", "type": 0, "deny": str(CONNECT), "allow": "0"}]}
        permissions = permissions_for(channel, "guild", [{"id": "guild", "permissions": str(ADMINISTRATOR)}], {"roles": [], "user": {"id": "bot"}})
        self.assertTrue(can_read_history(channel, permissions))

    def test_member_deny_wins_over_role_allow(self):
        roles = [{"id": "guild", "permissions": str(VIEW_CHANNEL | READ_MESSAGE_HISTORY)}, {"id": "bot-role", "permissions": "0"}]
        member = {"roles": ["bot-role"], "user": {"id": "bot"}}
        channel = {"permission_overwrites": [
            {"id": "guild", "type": 0, "allow": "0", "deny": str(VIEW_CHANNEL)},
            {"id": "bot-role", "type": 0, "allow": str(VIEW_CHANNEL), "deny": "0"},
            {"id": "bot", "type": 1, "allow": "0", "deny": str(VIEW_CHANNEL)},
        ]}
        self.assertFalse(permissions_for(channel, "guild", roles, member) & VIEW_CHANNEL)

    def test_role_overwrites_are_combined_before_applying(self):
        roles = [{"id": "guild", "permissions": "0"}]
        member = {"roles": ["allow", "deny"], "user": {"id": "bot"}}
        channel = {"permission_overwrites": [
            {"id": "allow", "type": 0, "allow": str(VIEW_CHANNEL), "deny": "0"},
            {"id": "deny", "type": 0, "allow": "0", "deny": str(VIEW_CHANNEL)},
        ]}
        self.assertTrue(permissions_for(channel, "guild", roles, member) & VIEW_CHANNEL)


class ArchiveTests(unittest.TestCase):
    def test_size_mismatch_requires_identical_bytes_from_source(self):
        for source_bytes, expected in [(b"preserved", 0), (b"different", 1)]:
            with self.subTest(source_bytes=source_bytes), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                (root / "attachment.txt").write_bytes(b"preserved")
                (root / "channel.json").write_text(json.dumps({"channel": {"id": "1"}, "messageCount": 1, "messages": [{"id": "2", "attachments": [{"id": "3", "url": "attachment.txt", "fileSizeBytes": 2}]}]}))
                client = Mock()
                client.get.return_value = {"attachments": [{"id": "3", "url": "https://cdn.discordapp.com/file", "size": 2}]}
                with patch("discord_migration.urlopen", return_value=io.BytesIO(source_bytes)), contextlib.redirect_stdout(io.StringIO()):
                    result = verify_archive(root, source_client=client)
                self.assertEqual(result, expected)

    def test_selected_channel_does_not_claim_coverage_of_partial_exports(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "complete.json").write_text(json.dumps({"channel": {"id": "1"}, "messageCount": 0, "messages": []}))
            (root / "partial.json").write_text('{"messages": [')
            with contextlib.redirect_stdout(io.StringIO()):
                selected = verify_archive(root, "1")
                missing = verify_archive(root, "2")
                whole = verify_archive(root)
            self.assertEqual(selected, 0)
            self.assertEqual(missing, 1)
            self.assertEqual(whole, 1)
            self.assertEqual(json.loads((root / "verification-1.json").read_text())["selected_channel_id"], "1")

    def test_missing_and_external_attachments_fail_verification(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "channel.json").write_text(json.dumps({"channel": {"id": "1"}, "messageCount": 1, "messages": [{"id": "2", "attachments": [{"id": "3", "url": "missing.png"}, {"id": "4", "url": "https://cdn.discordapp.com/attachment.png"}]}]}))
            with contextlib.redirect_stdout(io.StringIO()):
                result = verify_archive(root)
            self.assertEqual(result, 1)
            self.assertEqual(len(json.loads((root / "verification.json").read_text())["failures"]), 2)

    def test_local_attachment_is_hashed(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "attachment.txt").write_bytes(b"preserved")
            (root / "channel.json").write_text(json.dumps({"channel": {"id": "1"}, "messageCount": 1, "messages": [{"id": "2", "attachments": [{"id": "3", "url": "attachment.txt", "fileSizeBytes": 9}]}]}))
            with contextlib.redirect_stdout(io.StringIO()):
                result = verify_archive(root)
            self.assertEqual(result, 0)
            attachment = json.loads((root / "verification.json").read_text())["channels"][0]["attachments"][0]
            self.assertEqual(len(attachment["sha256"]), 64)


if __name__ == "__main__":
    unittest.main()
