#!/bin/bash
set -euo pipefail

if [[ "$(/usr/bin/uname -s)" != Darwin || "$(/bin/hostname -s)" != vega ]]; then
  echo 'This command switches Vega and must run on Vega.' >&2
  exit 2
fi

# Terminal opens .command files in the home directory, not the checkout.
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd -- "$repo_root"

printf 'Switching Vega from %s\n' "$repo_root"
printf '%s\n' 'If macOS blocks app updates, enable Terminal in System Settings > Privacy & Security > App Management, then run just switch again.'

if /usr/bin/sudo /run/current-system/sw/bin/darwin-rebuild switch --flake "$repo_root#vega"; then
  echo 'Vega switched successfully.'
else
  command_status=$?
  printf 'Vega switch failed (exit %s). See the output above.\n' "$command_status" >&2
  exit "$command_status"
fi
