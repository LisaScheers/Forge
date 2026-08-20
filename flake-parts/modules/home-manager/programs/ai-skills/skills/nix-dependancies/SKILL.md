---
name: nix-dependancies
description: this skill helps to find missing system packages.
metadata:
  harness: [codex]
  platform: [darwin, linux]
---
# Nix Dependancies
When you need a system package that is not installed, try to find the package in nixpkgs.
If there is a matching package you can use it with `nix-shell -p <package-name>`.

