#!/bin/bash
set -euo pipefail

if [[ "$(/usr/bin/uname -s)" != Darwin || "$(/bin/hostname -s)" != vega ]]; then
  echo 'This command cleans the Nix store on Vega and must run on Vega.' >&2
  exit 2
fi

printf '%s\n' 'Deleting old Nix profile generations and collecting unused store paths.'
printf '%s\n' 'If macOS blocks cleanup of .app bundles, enable Terminal in System Settings > Privacy & Security > App Management, then run just clean again.'

# Run locally under Terminal rather than forwarding GC to the launchd daemon.
if /usr/bin/sudo /run/current-system/sw/bin/nix-collect-garbage --store local -d; then
  echo 'Nix cleanup completed successfully.'
else
  command_status=$?
  printf 'Nix cleanup failed (exit %s). See the output above.\n' "$command_status" >&2
  exit "$command_status"
fi
