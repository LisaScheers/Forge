#!/usr/bin/env bash
# Print the Nix system of a deployable host from the flake's deploySystems output.
# Exit 2 for a malformed or unknown host; evaluation errors surface unchanged.
set -euo pipefail

host=${1:-}
# Host names become a Nix attribute name below, so only allow plain names.
if [[ ! "$host" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
  echo "unknown deploy host: $host" >&2
  exit 2
fi
target_system=$(nix eval --raw .#deploySystems --apply "systems: systems.\"$host\" or \"\"")
if [[ -z "$target_system" ]]; then
  echo "unknown deploy host: $host" >&2
  exit 2
fi
printf '%s\n' "$target_system"
