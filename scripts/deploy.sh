#!/usr/bin/env bash
set -euo pipefail

host=$1
mode=${2:-switch}
maintenance=${3:-}
if [[ -n "$maintenance" && ( "$maintenance" != "--maintenance" || "$host" != "atlas" || "$mode" != "switch" ) ]]; then
  echo "--maintenance requires an Atlas switch deployment" >&2
  exit 2
fi
target_system=$(bash "$(dirname -- "${BASH_SOURCE[0]}")/deploy-system.sh" "$host")

ssh_args=()
deploy_args=(--skip-checks)
if [[ -n "${FORGE_DEPLOY_SSH_CONTROL:-}" ]]; then
  ssh_args=(-S "$FORGE_DEPLOY_SSH_CONTROL")
  deploy_args+=(--ssh-opts "-S $FORGE_DEPLOY_SSH_CONTROL")
fi
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
  if [[ -n "$(git status --porcelain)" ]]; then
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

atlas_timer_needs_restart=0
atlas_timer_was_held=0
atlas_deploy_started=0
print_timer_restart() {
  echo "Start it when Atlas should update itself again:" >&2
  echo "  ssh ${ssh_args[*]} atlas sudo systemctl start nix-auto-sync-update.timer" >&2
}
restart_atlas_timer() {
  exit_status=$?
  trap - EXIT
  if [[ "$atlas_timer_needs_restart" == "1" ]]; then
    if [[ "$maintenance" == "--maintenance" || "$atlas_timer_was_held" == "1" ]]; then
      if ! ssh "${ssh_args[@]}" atlas sudo systemctl stop nix-auto-sync-update.timer; then
        echo "failed to keep the Atlas auto-update timer stopped" >&2
        exit_status=1
      elif [[ "$maintenance" == "--maintenance" ]]; then
        echo "Atlas maintenance: its auto-update timer remains stopped" >&2
      else
        echo "Atlas auto-update timer was stopped before this deploy; it remains stopped" >&2
        print_timer_restart
      fi
    elif [[ "$atlas_deploy_started" == "1" && "$exit_status" != "0" ]]; then
      # Activation and rollback can start wanted timers again.
      if ssh "${ssh_args[@]}" atlas sudo systemctl stop nix-auto-sync-update.timer; then
        echo "Atlas deployment failed; its auto-update timer remains stopped" >&2
      else
        echo "Atlas deployment failed; failed to stop its auto-update timer" >&2
      fi
      # A later deploy treats the stopped timer as a hold and keeps it.
      echo "Later deploys keep it stopped until it is started again." >&2
      print_timer_restart
    elif ! ssh "${ssh_args[@]}" atlas sudo systemctl start nix-auto-sync-update.timer; then
      echo "failed to restart Atlas auto-update timer" >&2
      exit_status=1
    fi
  fi
  exit "$exit_status"
}
trap restart_atlas_timer EXIT

if [[ "$host" == "atlas" ]]; then
  # An earlier hold (a timer already stopped by hand) outlasts this deploy.
  timer_state="$(ssh "${ssh_args[@]}" atlas systemctl show --property=ActiveState --value nix-auto-sync-update.timer)"
  if [[ "$timer_state" != "active" ]]; then
    atlas_timer_was_held=1
  fi
  atlas_timer_needs_restart=1
  ssh "${ssh_args[@]}" atlas sudo systemctl stop nix-auto-sync-update.timer
  update_state="$(ssh "${ssh_args[@]}" atlas systemctl show --property=ActiveState --value nix-auto-sync-update.service)"
  # A failed run must not block deploying the commit that fixes it.
  if [[ "$update_state" != "inactive" && "$update_state" != "failed" ]]; then
    echo "Atlas auto-update state is $update_state; it was not deployed" >&2
    exit 1
  fi
  reboot_state="$(ssh "${ssh_args[@]}" atlas systemctl show --property=ActiveState --value nix-auto-sync-update-reboot.timer)"
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
