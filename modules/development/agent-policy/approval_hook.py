"""Claude Code PreToolUse hook: shell commands that need Lisa's approval ask first.

Permission rules match only a command's prefix; this also catches the same
commands after `cd x &&`, `sudo` or inside a pipeline, and it applies in every
permission mode, including bypass.
"""

import json
import re
import sys


def decision(policy, event):
    if event.get("tool_name") != "Bash":
        return None
    command = (event.get("tool_input") or {}).get("command") or ""
    for rule in policy["commands"]:
        if re.search(rule["pattern"], command):
            return {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "ask",
                    "permissionDecisionReason": f"`{rule['command']}` changes a live system; Lisa approves it first.",
                }
            }
    return None


def main():
    with open(sys.argv[1], encoding="utf-8") as source:
        policy = json.load(source)
    result = decision(policy, json.load(sys.stdin))
    if result is not None:
        json.dump(result, sys.stdout)


if __name__ == "__main__":
    main()
