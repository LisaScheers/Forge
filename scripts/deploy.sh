#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 3 ]]; then
  echo "usage: deploy.sh <host> [switch|dry|test] [--maintenance]" >&2
  exit 2
fi
host=$1
mode=${2:-switch}
maintenance=${3:-}
if [[ -n "$maintenance" && ( "$maintenance" != "--maintenance" || "$host" != "atlas" || "$mode" != "switch" ) ]]; then
  echo "--maintenance requires an Atlas switch deployment" >&2
  exit 2
fi
deploy_args=(--skip-checks)
if [[ -n "${FORGE_DEPLOY_SSH_CONTROL:-}" ]]; then
  # deploy-rs splits --ssh-opts on whitespace, so such a path cannot reach it intact.
  if [[ "$FORGE_DEPLOY_SSH_CONTROL" =~ [[:space:]] ]]; then
    echo "FORGE_DEPLOY_SSH_CONTROL must not contain whitespace" >&2
    exit 2
  fi
  deploy_args+=(--ssh-opts "-S $FORGE_DEPLOY_SSH_CONTROL")
fi
# A function rather than an argument array: Bash 3.2 rejects an empty array
# under set -u.
# The arguments are the remote command, expanded locally on purpose.
# shellcheck disable=SC2029
atlas_ssh() {
  if [[ -n "${FORGE_DEPLOY_SSH_CONTROL:-}" ]]; then
    ssh -S "$FORGE_DEPLOY_SSH_CONTROL" atlas "$@"
  else
    ssh atlas "$@"
  fi
}
case "$mode" in
  switch) ;;
  dry) deploy_args+=(--dry-activate) ;;
  test) deploy_args+=(--test) ;;
  *)
    echo "unknown deploy mode: $mode" >&2
    exit 2
    ;;
esac

if [[ "$host" == "vega" ]]; then
  if [[ "$mode" != "switch" ]]; then
    echo "deploy-rs does not provide useful dry or test activation for nix-darwin" >&2
    exit 2
  fi
  if [[ "$(hostname -s)" != "vega" ]]; then
    echo "Vega can only be deployed manually from Vega" >&2
    exit 2
  fi
fi

# Arguments are all checked above, so a mistake fails before flake evaluation.
target_system=$(bash "$(dirname -- "${BASH_SOURCE[0]}")/deploy-system.sh" "$host")

# Percent-encode a checkout path for a git+file URL (spaces, '#', '?', ...).
url_encode_path() {
  local LC_ALL=C path=$1 encoded="" char index
  for ((index = 0; index < ${#path}; index++)); do
    char=${path:index:1}
    case "$char" in
      [A-Za-z0-9/._~-]) encoded+=$char ;;
      *) printf -v char '%%%02X' "'$char"; encoded+=$char ;;
    esac
  done
  printf '%s' "$encoded"
}

flake=.
if [[ "$host" == "atlas" ]]; then
  if ! worktree_changes="$(git status --porcelain)"; then
    echo "git status failed; Atlas was not deployed" >&2
    exit 1
  fi
  if [[ -n "$worktree_changes" ]]; then
    echo "Atlas deploys require a clean worktree" >&2
    exit 1
  fi

  git fetch --quiet origin main
  verified_rev="$(git rev-parse HEAD)"
  if [[ "$verified_rev" != "$(git rev-parse origin/main)" ]]; then
    echo "Atlas deploys require HEAD to match origin/main" >&2
    exit 1
  fi
  # Build and activate exactly the verified commit, not later worktree edits.
  flake="git+file://$(url_encode_path "$PWD")?rev=$verified_rev"
fi

nix build --no-link \
  "$flake#checks.$target_system.\"deploy-schema-$host\"" \
  "$flake#checks.$target_system.\"deploy-activate-$host\"" \
  "$flake#checks.$target_system.\"$host\""

atlas_timer_paused=0
atlas_timer_was_held=0
atlas_deploy_started=0
# The caller's optional SSH control socket may be gone by the time this is run,
# so the command uses a plain connection.
print_timer_restart() {
  echo "Start it when Atlas should update itself again:" >&2
  echo "  ssh atlas sudo systemctl start nix-auto-sync-update.timer" >&2
}
# On exit, after pausing the timer:
# - maintenance, an earlier hold or a failed deploy: stop it again. If the stop
#   succeeds, say it stays stopped and print the start command; if it fails,
#   say the timer may run and fail the deploy.
# - otherwise: start it again.
settle_atlas_timer() {
  exit_status=$?
  trap - EXIT
  if [[ "$atlas_timer_paused" == "1" ]]; then
    deploy_failed=0
    if [[ "$atlas_deploy_started" == "1" && "$exit_status" != "0" ]]; then
      deploy_failed=1
    fi
    if [[ "$maintenance" == "--maintenance" || "$atlas_timer_was_held" == "1" || "$deploy_failed" == "1" ]]; then
      # Stop it again: activation and rollback can start wanted timers.
      if ! atlas_ssh sudo systemctl stop nix-auto-sync-update.timer; then
        echo "failed to keep the Atlas auto-update timer stopped; it may run again" >&2
        if [[ "$exit_status" == "0" ]]; then
          exit_status=1
        fi
      else
        if [[ "$maintenance" == "--maintenance" ]]; then
          echo "Atlas maintenance: its auto-update timer remains stopped" >&2
        elif [[ "$atlas_timer_was_held" == "1" ]]; then
          echo "Atlas auto-update timer was stopped before this deploy; it remains stopped" >&2
        else
          # A later deploy treats the stopped timer as a hold and keeps it.
          echo "Atlas deployment failed; its auto-update timer remains stopped, and later deploys keep it stopped" >&2
        fi
        print_timer_restart
      fi
    elif ! atlas_ssh sudo systemctl start nix-auto-sync-update.timer; then
      echo "failed to restart Atlas auto-update timer" >&2
      exit_status=1
    fi
  fi
  exit "$exit_status"
}
trap settle_atlas_timer EXIT

if [[ "$host" == "atlas" ]]; then
  # An earlier hold (a timer stopped by hand or by a failed deploy) outlasts
  # this deploy. A timer that failed on its own is not a hold.
  timer_state="$(atlas_ssh systemctl show --property=ActiveState --value nix-auto-sync-update.timer)"
  if [[ "$timer_state" == "inactive" ]]; then
    atlas_timer_was_held=1
  fi
  atlas_timer_paused=1
  atlas_ssh sudo systemctl stop nix-auto-sync-update.timer
  update_state="$(atlas_ssh systemctl show --property=ActiveState --value nix-auto-sync-update.service)"
  # A failed run must not block deploying the commit that fixes it.
  if [[ "$update_state" != "inactive" && "$update_state" != "failed" ]]; then
    echo "Atlas auto-update state is $update_state; it was not deployed" >&2
    exit 1
  fi
  reboot_state="$(atlas_ssh systemctl show --property=ActiveState --value nix-auto-sync-update-reboot.timer)"
  if [[ "$reboot_state" != "inactive" ]]; then
    echo "Atlas reboot timer state is $reboot_state; it was not deployed" >&2
    exit 1
  fi

  # Close the race where main changes while the closures are building.
  git fetch --quiet origin main
  if [[ "$(git rev-parse origin/main)" != "$verified_rev" ]]; then
    echo "origin/main changed while building; Atlas was not deployed" >&2
    exit 1
  fi
fi

# The three host checks built above are the deployment gate; CI builds the rest.
if [[ "$host" == "atlas" ]]; then
  atlas_deploy_started=1
fi
nix run "$flake#deploy" -- "${deploy_args[@]}" "$flake#$host"
