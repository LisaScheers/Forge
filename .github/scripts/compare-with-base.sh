#!/usr/bin/env bash
set -euo pipefail

# On pull requests, BASE_REVISION names the commit the pull request merges into.
# When the job's target and checks evaluate to the same derivations there, the
# base branch's own run already built them, so the job reports changed=false
# and skips its build. Anything that prevents the comparison keeps the build.
installables=(".#$TARGET")
# Bash 3.2 treats an empty array as unset under set -u, so split only a
# non-empty list.
if [[ -n "${CHECKS:-}" ]]; then
  read -ra checks <<< "$CHECKS"
  for check in "${checks[@]}"; do
    installables+=(".#$check")
  done
fi

derivations() {
  nix path-info --derivation --no-write-lock-file "$@" | sort
}

changed=true
if [[ -n "${BASE_REVISION:-}" ]] && base=$(git rev-parse --verify --quiet "$BASE_REVISION^{commit}"); then
  base_installables=()
  for installable in "${installables[@]}"; do
    base_installables+=("git+file://$PWD?shallow=1&rev=$base${installable#.}")
  done
  if head_derivations=$(derivations "${installables[@]}") &&
    base_derivations=$(derivations "${base_installables[@]}") &&
    [[ -n "$head_derivations" && "$head_derivations" == "$base_derivations" ]]; then
    changed=false
    echo "::notice::$TARGET matches $base; skipping its build."
  fi
fi
echo "changed=$changed" >> "$GITHUB_OUTPUT"
