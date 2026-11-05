"""Render the proxy's private runtime config from systemd credentials."""

import json
import hashlib
import os
from pathlib import Path
import sys


def render(template, credential_dir, destination):
    os.umask(0o077)
    settings = json.loads(template.read_text())
    settings["api-keys"] = [(credential_dir / "client-key").read_text().strip()]
    settings["openai-compatibility"][0]["api-key-entries"] = [
        {"api-key": (credential_dir / "openrouter-key").read_text().strip()}
    ]
    auth_dir = Path(settings["auth-dir"])
    auth_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
    for provider in ("codex", "antigravity"):
        credential = credential_dir / f"{provider}-auth"
        if not credential.exists():
            continue
        auth = auth_dir / f"{provider}.json"
        seed = credential.read_bytes()
        seed_hash = hashlib.sha256(seed).hexdigest()
        marker = auth_dir / f".{provider}-seed-sha256"
        # Preserve refreshes performed by CLIProxy. Replace only on explicit seed rotation.
        if not auth.exists() or not marker.exists() or marker.read_text() != seed_hash:
            temporary = auth.with_suffix(".tmp")
            temporary.write_bytes(seed)
            temporary.chmod(0o600)
            temporary.replace(auth)
            marker.write_text(seed_hash)
        if provider == "codex":
            # Native control frames must reach the same upstream WebSocket.
            # Update capability metadata without replacing refreshed OAuth tokens.
            current = json.loads(auth.read_text())
            if current.get("websockets") is not True:
                current["websockets"] = True
                temporary = auth.with_suffix(".tmp")
                temporary.write_text(json.dumps(current))
                temporary.chmod(0o600)
                temporary.replace(auth)
    destination.write_text(json.dumps(settings))
    destination.chmod(0o600)


if __name__ == "__main__":
    render(Path(sys.argv[1]), Path(os.environ["CREDENTIALS_DIRECTORY"]), Path(sys.argv[2]))
