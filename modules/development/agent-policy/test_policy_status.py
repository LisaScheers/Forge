import json
import tempfile
import unittest
from pathlib import Path

from policy_status import differences

EXPECTED = {
    "codex": {"sandbox_mode": "danger-full-access", "approval_policy": "never"},
    "claude": {"permissions": {"defaultMode": "bypassPermissions", "deny": ["Read(~/.ssh/id_*)"], "ask": []},
               "hooks": {"PreToolUse": []}},
    "codex_servers": {"omit_tools_from": ["direct"]},
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

    def test_settings_left_from_the_approval_policy_are_reported(self):
        home = self.home('approval_policy = "on-request"\nsandbox_mode = "workspace-write"\n',
                         {"permissions": {"defaultMode": "default"}})
        found = "\n".join(differences(EXPECTED, home))
        self.assertIn("sandbox_mode is 'workspace-write'", found)
        self.assertIn("approval_policy is 'on-request'", found)
        self.assertIn("permissions.defaultMode is 'default'", found)
        self.assertIn("permissions.deny lacks Read(~/.ssh/id_*)", found)

    def test_merged_settings_with_extra_rules_match(self):
        claude = {"permissions": {"defaultMode": "bypassPermissions",
                                  "deny": ["Read(~/.ssh/id_*)", "Read(~/mine)"]}}
        home = self.home('approval_policy = "never"\nsandbox_mode = "danger-full-access"\nmodel = "x"\n', claude)
        self.assertEqual(differences(EXPECTED, home), [])

    def test_keys_inside_owned_servers_that_nix_dropped_are_reported(self):
        claude = {"permissions": {"defaultMode": "bypassPermissions", "deny": ["Read(~/.ssh/id_*)"]}}
        home = self.home('approval_policy = "never"\nsandbox_mode = "danger-full-access"\n'
                         '[mcp_servers.clerk_mcp]\nurl = "u"\ndefault_tools_approval_mode = "prompt"\n'
                         'omit_tools_from = ["direct"]\n'
                         '[mcp_servers.node_repl]\ncommand = "node"\n', claude)
        found = differences(EXPECTED, home, [["mcp_servers", "clerk_mcp", "url"],
                                             ["mcp_servers", "clerk_mcp", "omit_tools_from"]])
        self.assertEqual(found, [f"{home}/.codex/config.toml: mcp_servers.clerk_mcp.default_tools_approval_mode "
                                 "is not declared by Nix"])

    def test_restored_ask_rules_hooks_and_loaded_servers_are_reported(self):
        claude = {"permissions": {"defaultMode": "bypassPermissions", "deny": ["Read(~/.ssh/id_*)"],
                                  "ask": ["Bash(just deploy:*)"]},
                  "hooks": {"PreToolUse": [{"matcher": "Bash"}]}}
        home = self.home('approval_policy = "never"\nsandbox_mode = "danger-full-access"\n'
                         '[mcp_servers.rea]\ncommand = "rea"\n', claude)
        found = "\n".join(differences(EXPECTED, home, [["mcp_servers", "rea", "command"],
                                                        ["mcp_servers", "rea", "omit_tools_from"]]))
        self.assertIn("permissions.ask is ['Bash(just deploy:*)'], policy says []", found)
        self.assertIn("hooks.PreToolUse is [{'matcher': 'Bash'}], policy says []", found)
        self.assertIn("mcp_servers.rea.omit_tools_from is None, policy says ['direct']", found)

    def test_missing_files_are_differences(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.assertEqual(len(differences(EXPECTED, Path(directory.name))), 4)


if __name__ == "__main__":
    unittest.main()
