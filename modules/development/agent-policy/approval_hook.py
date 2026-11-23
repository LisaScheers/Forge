"""PreToolUse hook for Claude Code and Codex: live-system commands need Lisa.

Permission rules match only a command's prefix; this also catches the same
commands after `cd x &&`, `sudo`, `nix run` or a pipe. Claude asks in every
permission mode, including bypass. Codex hooks cannot ask, and its prefix rules
already prompt in modes that ask, so for Codex the hook blocks these commands
only in modes that never prompt.

Usage: approval_hook.py POLICY_JSON claude|codex
"""

import json
import re
import sys

# Codex permission modes in which nothing reaches Lisa before a command runs.
UNPROMPTED_CODEX_MODES = {"bypassPermissions", "dontAsk"}


def output(decision, reason):
    return {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": decision,
            "permissionDecisionReason": reason,
        }
    }


def live_command(policy, event):
    if event.get("tool_name") != "Bash":
        return None
    command = (event.get("tool_input") or {}).get("command") or ""
    for rule in policy["commands"]:
        if re.search(rule["pattern"], command):
            return rule["command"]
    return None


def decision(policy, event, client="claude"):
    # AGENTS.md: delegated agents do not start agents of their own.
    if client == "claude" and event.get("tool_name") in ("Agent", "Task") and event.get("agent_id"):
        return output("deny", "Subagents do not start subagents; return this work to the main agent.")
    command = live_command(policy, event)
    if command is None:
        return None
    reason = f"`{command}` changes a live system; Lisa approves it first."
    if client == "claude":
        return output("ask", reason)
    if event.get("permission_mode") in UNPROMPTED_CODEX_MODES:
        return output("deny", reason + " This Codex mode cannot ask, so ask Lisa to approve it in a mode that prompts.")
    return None


def main():
    with open(sys.argv[1], encoding="utf-8") as source:
        policy = json.load(source)
    client = sys.argv[2] if len(sys.argv) > 2 else "claude"
    result = decision(policy, json.load(sys.stdin), client)
    if result is not None:
        json.dump(result, sys.stdout)


if __name__ == "__main__":
    main()
