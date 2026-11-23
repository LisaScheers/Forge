import json
import os
import unittest

from approval_hook import decision

with open(os.environ["AGENT_POLICY"], encoding="utf-8") as source:
    POLICY = json.load(source)


def bash(command, **fields):
    return {"tool_name": "Bash", "tool_input": {"command": command}, **fields}


class ApprovalHookTests(unittest.TestCase):
    def assert_asks(self, command):
        result = decision(POLICY, bash(command))
        self.assertIsNotNone(result, command)
        self.assertEqual(result["hookSpecificOutput"]["permissionDecision"], "ask")

    def assert_allows(self, command):
        self.assertIsNone(decision(POLICY, bash(command)), command)

    def test_live_system_commands_ask(self):
        for command in [
            "just deploy nook",
            "just switch",
            "cd ~/forge && just deploy atlas test",
            "sudo darwin-rebuild switch --flake .#vega",
            "nixos-rebuild switch --flake .#asterion",
            "bash scripts/deploy.sh nook switch",
            "home-manager switch --flake .#lisa@nook",
            "deploy .#nook",
            "./scripts/deploy.sh atlas dry",
            "git pull && just deploy-maintenance",
            "nix run nix-darwin -- switch --flake .#vega",
            "nix run nixpkgs#nixos-rebuild -- switch --flake .#asterion",
            "nix run home-manager/master -- switch --flake .",
        ]:
            self.assert_asks(command)

    def test_builds_and_reads_pass(self):
        for command in [
            "just deploy-build nook",
            "just check",
            "nix build .#checks.aarch64-darwin.agent-policy",
            "git log --oneline -5",
            "darwin-rebuild build --flake .#vega",
            "cat docs/deploy.md",
        ]:
            self.assert_allows(command)

    def test_codex_blocks_only_where_it_cannot_ask(self):
        command = "cd ~/forge && just deploy nook"
        for mode in ["bypassPermissions", "dontAsk"]:
            result = decision(POLICY, bash(command, permission_mode=mode), "codex")
            self.assertEqual(result["hookSpecificOutput"]["permissionDecision"], "deny", mode)
        # Codex's prefix rules prompt in these modes; the hook stays out of the way.
        for mode in ["default", "acceptEdits", None]:
            self.assertIsNone(decision(POLICY, bash(command, permission_mode=mode), "codex"), mode)
        self.assertIsNone(decision(POLICY, bash("just check", permission_mode="bypassPermissions"), "codex"))

    def test_subagents_do_not_start_subagents(self):
        nested = {"tool_name": "Agent", "agent_id": "agent-1", "tool_input": {"prompt": "x"}}
        self.assertEqual(decision(POLICY, nested)["hookSpecificOutput"]["permissionDecision"], "deny")
        self.assertIsNone(decision(POLICY, {"tool_name": "Agent", "tool_input": {"prompt": "x"}}))
        self.assertIsNone(decision(POLICY, nested, "codex"))

    def test_other_tools_pass(self):
        self.assertIsNone(decision(POLICY, {"tool_name": "Read", "tool_input": {"file_path": "x"}}))
        self.assertIsNone(decision(POLICY, {"tool_name": "Bash", "tool_input": {}}))


if __name__ == "__main__":
    unittest.main()
