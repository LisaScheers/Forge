#!/usr/bin/env bash
set -euo pipefail

build_log=$(mktemp)
trap 'rm -f "$build_log"' EXIT

for attempt in 1 2 3; do
  if nix build --no-link --no-write-lock-file --print-build-logs ".#$TARGET" 2>&1 | tee "$build_log"; then
    exit 0
  else
    build_exit=$?
  fi

  # Retry transient DNS failures in place, retaining the completed store paths.
  # Compilation and test failures without a DNS error fail immediately.
  if [[ "$attempt" == 3 ]] || ! grep -q 'curl: (6) Could not resolve host:' "$build_log"; then
    exit "$build_exit"
  fi
  echo "DNS lookup failed; retrying build in 30 seconds (attempt $((attempt + 1))/3)."
  sleep 30
done
