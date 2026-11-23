import json
import tempfile
import unittest
from pathlib import Path

from policy_status import differences

EXPECTED = {
    "codex": {"sandbox_mode": "workspace-write", "approval_policy": "on-request"},
    "claude": {"permissions": {"ask": ["Bash(just deploy:*)"], "deny": ["Read(~/.ssh/id_*)"]}, "hook": "hook"},
    "codex_hook": "codex-hook",
    "codex_rules": "prefix_rule(pattern = [\"just\", \"deploy\"], decision = \"prompt\")\n",
}
CODEX_HOOKS = {"hooks": {"PreToolUse": [{"matcher": "^Bash$", "hooks": [{"type": "command", "command": "codex-hook"}]}]}}


class PolicyStatusTests(unittest.TestCase):
    def home(self, codex, claude, codex_hooks=None, rules=None):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        home = Path(directory.name)
        (home / ".codex").mkdir()
        (home / ".codex" / "config.toml").write_text(codex)
        (home / ".claude").mkdir()
        (home / ".claude" / "settings.json").write_text(json.dumps(claude))
        if codex_hooks is not None:
            (home / ".codex" / "hooks.json").write_text(json.dumps(codex_hooks))
        if rules is not None:
            (home / ".codex" / "rules").mkdir()
            (home / ".codex" / "rules" / "agent-policy.rules").write_text(rules)
        return home

    def test_settings_left_from_before_the_policy_are_reported(self):
        home = self.home('approval_policy = "never"\nsandbox_mode = "danger-full-access"\n', {"theme": "dark"})
        found = "\n".join(differences(EXPECTED, home))
        self.assertIn("sandbox_mode is 'danger-full-access'", found)
        self.assertIn("approval_policy is 'never'", found)
        self.assertIn("permissions.ask lacks Bash(just deploy:*)", found)
        self.assertIn("approval hook", found)
        self.assertIn("hooks.json: the approval hook", found)
        self.assertIn("agent-policy.rules: the approval rules are missing", found)

    def test_merged_settings_with_extra_rules_match(self):
        claude = {
            "permissions": {"ask": ["Bash(just deploy:*)", "Bash(mine:*)"], "deny": ["Read(~/.ssh/id_*)"]},
            "hooks": {"PreToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": "hook"}]}]},
        }
        home = self.home('approval_policy = "on-request"\nsandbox_mode = "workspace-write"\nmodel = "x"\n', claude,
                         CODEX_HOOKS, EXPECTED["codex_rules"])
        self.assertEqual(differences(EXPECTED, home), [])

    def test_edited_codex_rules_are_reported(self):
        claude = {"permissions": {"ask": ["Bash(just deploy:*)"], "deny": ["Read(~/.ssh/id_*)"]},
                  "hooks": {"PreToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": "hook"}]}]}}
        home = self.home('approval_policy = "on-request"\nsandbox_mode = "workspace-write"\n', claude,
                         CODEX_HOOKS, "")
        self.assertEqual(len(differences(EXPECTED, home)), 1)

    def test_missing_files_are_differences(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.assertEqual(len(differences(EXPECTED, Path(directory.name))), 7)


if __name__ == "__main__":
    unittest.main()
