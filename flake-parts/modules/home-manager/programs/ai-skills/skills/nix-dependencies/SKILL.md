---
name: nix-dependencies
description: Use when a local command is blocked by a missing executable or system library that may be supplied temporarily from nixpkgs. Do not use it to change persistent configuration unless the user asks.
metadata:
  harness: [codex]
  platform: [darwin, linux]
---

# Nix dependencies

Use this skill when a local task is blocked by a missing executable or system library.

1. Identify the missing command or library from the actual error.
2. Search nixpkgs for the matching package attribute.
3. Prefer `nix shell nixpkgs#<package> -c <command>` for a temporary environment. Use `nix-shell -p <package>` when the repository already uses the legacy command.
4. Run the blocked command and report whether the package resolved the error.

Do not run Home Manager, modify persistent package lists, or activate a system configuration unless the user requested that change. If nixpkgs has no clear match, report what was searched and the remaining error instead of guessing.
