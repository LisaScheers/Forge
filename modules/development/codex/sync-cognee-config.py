"""Update only the declarative Cognee MCP entry in Codex's mutable config."""

import os
from pathlib import Path
import sys
import tempfile

import tomlkit

config_file, defaults_file = map(Path, sys.argv[1:])
document = tomlkit.parse(config_file.read_text())
defaults = tomlkit.parse(defaults_file.read_text())
servers = document.setdefault("mcp_servers", tomlkit.table())
entry = servers.setdefault("cognee", tomlkit.table())
for key, value in defaults["mcp_servers"]["cognee"].items():
    entry[key] = value
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
