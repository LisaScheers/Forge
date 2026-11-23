import json
import tempfile
import unittest
from pathlib import Path

from policy_status import differences

EXPECTED = {
    "codex": {"sandbox_mode": "workspace-write", "approval_policy": "on-request"},
    "claude": {"permissions": {"ask": ["Bash(just deploy:*)"], "deny": ["Read(~/.ssh/id_*)"]}, "hook": "hook"},
}


class PolicyStatusTests(unittest.TestCase):
    def home(self, codex, claude):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        home = Path(directory.name)
        (home / ".codex").mkdir()
        (home / ".codex" / "config.toml").write_text(codex)
        (home / ".claude").mkdir()
        (home / ".claude" / "settings.json").write_text(json.dumps(claude))
        return home

    def test_settings_left_from_before_the_policy_are_reported(self):
        home = self.home('approval_policy = "never"\nsandbox_mode = "danger-full-access"\n', {"theme": "dark"})
        found = "\n".join(differences(EXPECTED, home))
        self.assertIn("sandbox_mode is 'danger-full-access'", found)
        self.assertIn("approval_policy is 'never'", found)
        self.assertIn("permissions.ask lacks Bash(just deploy:*)", found)
        self.assertIn("approval hook", found)

    def test_merged_settings_with_extra_rules_match(self):
        claude = {
            "permissions": {"ask": ["Bash(just deploy:*)", "Bash(mine:*)"], "deny": ["Read(~/.ssh/id_*)"]},
            "hooks": {"PreToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": "hook"}]}]},
        }
        home = self.home('approval_policy = "on-request"\nsandbox_mode = "workspace-write"\nmodel = "x"\n', claude)
        self.assertEqual(differences(EXPECTED, home), [])

    def test_missing_files_are_differences(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.assertEqual(len(differences(EXPECTED, Path(directory.name))), 5)


if __name__ == "__main__":
    unittest.main()
