#!/usr/bin/env bash
set -euo pipefail

build_log=$(mktemp)
trap 'rm -f "$build_log"' EXIT

# CHECKS names flake checks that share the target's closure, such as a host's
# deploy-rs checks, so one job builds them together.
installables=(".#$TARGET")
for check in ${CHECKS:-}; do
  installables+=(".#$check")
done

for attempt in 1 2 3; do
  if nix build --no-link --no-write-lock-file --print-build-logs "${installables[@]}" 2>&1 | tee "$build_log"; then
    exit 0
  else
    build_exit=$?
  fi

  # Retain completed store paths when DNS or a resumed cache download fails.
  if [[ "$attempt" == 3 ]] || ! grep -Eq 'curl: \(6\) Could not resolve host:|error: unable to download .https://cache\.nixos\.org/nar/.*: HTTP error 416 ' "$build_log"; then
    exit "$build_exit"
  fi
  echo "Download failed; retrying build in 30 seconds (attempt $((attempt + 1))/3)."
  sleep 30
done
