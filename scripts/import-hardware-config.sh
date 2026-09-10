#!/usr/bin/env bash
set -euo pipefail

host=$1
source_file=$2
case "$host" in
  ''|*[!a-z0-9-]*) echo 'Expected a lowercase NixOS host name.' >&2; exit 1 ;;
esac

repo_root=$(git rev-parse --show-toplevel)
destination="$repo_root/flake-parts/hosts/$host/hardware-configuration.nix"
test -f "$destination" || { echo "No existing hardware feature for $host." >&2; exit 1; }
nix-instantiate --parse "$source_file" >/dev/null

# Write beside the target so the final replacement is atomic.
hardware_tmp=$(mktemp "$destination.XXXXXX")
trap 'rm -f "$hardware_tmp"' EXIT
{
  printf '{...}: {\n  forge.modules.nixos.%s =\n' "$host"
  cat "$source_file"
  printf '\n;\n}\n'
} >"$hardware_tmp"
nix-instantiate --parse "$hardware_tmp" >/dev/null
chmod 644 "$hardware_tmp"
mv "$hardware_tmp" "$destination"
