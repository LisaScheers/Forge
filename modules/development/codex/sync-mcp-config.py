"""Sync named declarative MCP entries while preserving Codex's mutable config."""

import os
from pathlib import Path
import sys
import tempfile

import tomlkit

config_file, defaults_file = map(Path, sys.argv[1:3])
managed_names = sys.argv[3:]
document = tomlkit.parse(config_file.read_text())
defaults = tomlkit.parse(defaults_file.read_text())
for name in managed_names:
    server = defaults.get("mcp_servers", {}).get(name)
    if server is not None and not (server.get("command") or server.get("url")):
        sys.exit(f"Refusing incomplete MCP registration: {name} has no command or URL")
servers = document.setdefault("mcp_servers", tomlkit.table())
for name in managed_names:
    if name in defaults.get("mcp_servers", {}):
        servers[name] = defaults["mcp_servers"][name]
    else:
        servers.pop(name, None)
rendered = tomlkit.dumps(document)
if rendered != config_file.read_text():
    descriptor, temporary = tempfile.mkstemp(dir=config_file.parent)
    try:
        with os.fdopen(descriptor, "w") as output:
            output.write(rendered)
        os.replace(temporary, config_file)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
