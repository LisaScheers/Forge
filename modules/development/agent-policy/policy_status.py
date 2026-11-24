"""Compare the live agent settings with agent-policy.nix.

The flake check proves what Nix declares; mutable settings files can still
differ until the next activation, or after an app or a person edits them.
Usage: policy_status.py EXPECTED_JSON HOME [OWNED_SERVERS_JSON]. Exits 1 and
names each difference. OWNED_SERVERS_JSON lists the leaf key paths Nix sets in
Codex's MCP server tables; any other key inside those tables is drift.
"""

import json
import sys
import tomllib
from pathlib import Path


def leaf_paths(value, prefix=()):
    if isinstance(value, dict) and value:
        return [path for key, child in value.items() for path in leaf_paths(child, prefix + (key,))]
    return [prefix]


def differences(expected, home, owned=()):
    found = []
    codex_path = home / ".codex" / "config.toml"
    try:
        codex = tomllib.loads(codex_path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        codex = {}
    for key, value in expected["codex"].items():
        if codex.get(key) != value:
            found.append(f"{codex_path}: {key} is {codex.get(key)!r}, policy says {value!r}")
    claude_path = home / ".claude" / "settings.json"
    try:
        claude = json.loads(claude_path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        claude = {}
    for section, rules in expected["claude"].items():
        actual = claude.get(section) or {}
        for key, value in rules.items():
            name = f"{claude_path}: {section}.{key}"
            if value == []:
                # Nothing allowed: an ask rule or hook added after activation is drift.
                if actual.get(key):
                    found.append(f"{name} is {actual.get(key)!r}, policy says []")
            elif isinstance(value, list):
                # Required rules; the app or a person may add more.
                missing = [rule for rule in value if rule not in (actual.get(key) or [])]
                if missing:
                    found.append(f"{name} lacks {', '.join(missing)}")
            elif actual.get(key) != value:
                found.append(f"{name} is {actual.get(key)!r}, policy says {value!r}")
    owned = {tuple(path) for path in owned}
    for server in sorted({path[1] for path in owned}):
        table = (codex.get("mcp_servers") or {}).get(server)
        if not table:
            continue
        for path in leaf_paths(table, ("mcp_servers", server)):
            if path not in owned:
                found.append(f"{codex_path}: {'.'.join(path)} is not declared by Nix")
        for key, value in expected.get("codex_servers", {}).items():
            if table.get(key) != value:
                found.append(f"{codex_path}: mcp_servers.{server}.{key} is {table.get(key)!r}, policy says {value!r}")
    return found


def main():
    expected = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    owned = json.loads(Path(sys.argv[3]).read_text(encoding="utf-8")) if len(sys.argv) > 3 else []
    found = differences(expected, Path(sys.argv[2]), owned)
    for difference in found:
        print(difference, file=sys.stderr)
    if found:
        sys.exit(1)
    print("Live agent settings match agent-policy.nix")


if __name__ == "__main__":
    main()
