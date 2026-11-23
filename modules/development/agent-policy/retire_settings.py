"""Remove agent settings that Nix used to declare and no longer does.

Home Manager's mutable merge only adds and overwrites keys, so a declaration
removed from Nix stays in a writable settings file (Codex's config.toml, Claude's
and Antigravity's settings.json) forever. This keeps a manifest of the keys Nix
declared at the last activation and deletes those that are gone now. Keys the
app or Lisa added themselves were never in the manifest, so they stay.

Usage: retire_settings.py CONFIG MANIFEST DECLARED_JSON RETIRED_JSON
CONFIG is TOML or JSON, by its extension. DECLARED_JSON and RETIRED_JSON hold
key paths, such as ["mcp_servers", "rea"]. RETIRED_JSON names keys Nix declared
before this manifest existed.
"""

import json
import os
import sys
import tempfile
import tomllib
from pathlib import Path

import tomli_w


def load_paths(path):
    return {tuple(entry) for entry in json.loads(Path(path).read_text(encoding="utf-8"))}


def retire(config, paths):
    removed = []
    for path in sorted(paths):
        parent = config
        for key in path[:-1]:
            parent = parent.get(key)
            if not isinstance(parent, dict):
                break
        else:
            if path[-1] in parent:
                del parent[path[-1]]
                removed.append(".".join(path))
                # Drop a table that only held the retired key.
                if len(path) > 1 and parent == {}:
                    del config[path[0]]
    return removed


def main():
    config_path, manifest_path = Path(sys.argv[1]), Path(sys.argv[2])
    declared = load_paths(sys.argv[3])
    previous = load_paths(manifest_path) if manifest_path.exists() else set()
    stale = (previous | load_paths(sys.argv[4])) - declared
    if config_path.exists() and stale:
        is_toml = config_path.suffix == ".toml"
        text = config_path.read_text(encoding="utf-8")
        config = tomllib.loads(text) if is_toml else json.loads(text)
        removed = retire(config, stale)
        if removed:
            # Replace the file in one step, keeping its private mode.
            handle, temporary = tempfile.mkstemp(dir=config_path.parent, prefix=f".{config_path.name}.")
            with os.fdopen(handle, "w", encoding="utf-8") as output:
                output.write(tomli_w.dumps(config) if is_toml else json.dumps(config, indent=2) + "\n")
            os.chmod(temporary, 0o600)
            os.replace(temporary, config_path)
            print(f"Removed settings Nix no longer declares from {config_path}: " + ", ".join(removed))
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(sorted(declared)), encoding="utf-8")


if __name__ == "__main__":
    main()
