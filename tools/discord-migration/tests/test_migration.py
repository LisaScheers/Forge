import contextlib
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from discord_migration import READ_MESSAGE_HISTORY, VIEW_CHANNEL, permissions_for, verify_archive


class PermissionTests(unittest.TestCase):
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
