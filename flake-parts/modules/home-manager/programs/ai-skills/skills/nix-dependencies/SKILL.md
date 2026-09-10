---
name: nix-dependencies
description: Use when a standalone helper has known external requirements, or a local command is blocked by a missing executable, system library, Python module, or interpreter-version mismatch that may be supplied temporarily from nixpkgs. Do not use it to change persistent configuration unless the user asks.
metadata:
  harness: [codex]
  platform: [darwin, linux]
---

# Nix dependencies

Use this skill to select one suitable temporary runtime before executing a standalone helper with known external requirements, or after a local command fails because a dependency is unavailable.

1. For a helper with known requirements, identify its required commands, libraries, interpreter version, and modules before execution. After an unexpected failure, identify the missing requirement from the actual error.
2. Prefer the project's declared environment when it supplies every requirement. Otherwise, search nixpkgs for the matching package attributes and select one temporary environment containing every required command, library, interpreter, and module.
3. Verify the selected interpreter version and required imports, then execute the actual helper inside that same environment.
4. Prefer `nix shell nixpkgs#<package> -c <command>` for a temporary environment. Pass each required installable before `-c`, or use one package expression that combines them. Use `nix-shell -p <package>` when the repository already uses the legacy command or when an expression such as `python3.withPackages` is needed; pass multiple packages after `-p` when necessary.
5. Report whether the selected runtime resolved the dependency failure and whether the actual helper succeeded.

For Python helpers, select a new enough interpreter as well as its modules. `tomllib` requires Python 3.11 or later, while PyYAML is installed as `pyyaml` and imported as `yaml`. For example:

```sh
nix-shell -p 'python3.withPackages (ps: [ ps.pyyaml ])' \
  --run 'python3 -B -c "import yaml, tomllib; print(\"helper imports ok\")"'
```

Do not install global Python packages, run Home Manager, modify persistent package lists, or activate a system configuration unless the user requested that change. If nixpkgs has no clear match, report what was searched and the remaining error instead of guessing.
