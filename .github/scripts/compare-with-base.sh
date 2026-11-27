#!/usr/bin/env bash
set -euo pipefail

# On pull requests, BASE_REVISION names the commit the pull request merges into.
# The job reports changed=false, skipping its build, only when the pull request
# leaves the build workflow alone, the base's matrix has the same job on the
# same runner, and the job's target and checks evaluate to the same derivations
# there. The push run on main builds them after merge. Anything that prevents
# the comparison keeps the build.
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

in_base_matrix() {
  nix eval --json --no-write-lock-file --option allow-import-from-derivation false "$base_flake#ciMatrix.include" |
    jq -e --arg target "$TARGET" --arg checks "${CHECKS:-}" --arg runner "$RUNNER" \
      'any(.[]; .target == $target and .checks == $checks and .runner == $runner)' > /dev/null
}

changed=true
if [[ -n "${BASE_REVISION:-}" ]] &&
  base=$(git rev-parse --verify --quiet "$BASE_REVISION^{commit}") &&
  git diff --quiet "$base" HEAD -- .github; then
  base_flake="git+file://$PWD?shallow=1&rev=$base"
  base_installables=()
  for installable in "${installables[@]}"; do
    base_installables+=("$base_flake${installable#.}")
  done
  if in_base_matrix &&
    head_derivations=$(derivations "${installables[@]}") &&
    base_derivations=$(derivations "${base_installables[@]}") &&
    [[ -n "$head_derivations" && "$head_derivations" == "$base_derivations" ]]; then
    changed=false
    echo "::notice::$TARGET matches $base; skipping its build."
  fi
fi
echo "changed=$changed" >> "$GITHUB_OUTPUT"
