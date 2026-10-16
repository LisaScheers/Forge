#!/usr/bin/env bash
set -euo pipefail

host=$1
mode=${2:-switch}
maintenance=${3:-}
if [[ -n "$maintenance" && ( "$maintenance" != "--maintenance" || "$host" != "atlas" || "$mode" != "switch" ) ]]; then
  echo "--maintenance requires an Atlas switch deployment" >&2
  exit 2
fi
case "$host" in
  nook|atlas|vega) ;;
  *)
    echo "unknown deploy host: $host" >&2
    exit 2
    ;;
esac

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

if [[ "$host" == "atlas" ]]; then
  if [[ -n "$(git status --porcelain)" ]]; then
    echo "Atlas deploys require a clean worktree" >&2
    exit 1
  fi

  git fetch --quiet origin main
  if [[ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]]; then
    echo "Atlas deploys require HEAD to match origin/main" >&2
    exit 1
  fi
fi

case "$host" in
  nook|atlas) target_system="x86_64-linux" ;;
  vega) target_system="aarch64-darwin" ;;
esac
nix build --no-link \
  ".#checks.$target_system.deploy-schema-$host" \
  ".#checks.$target_system.deploy-activate-$host" \
  ".#checks.$target_system.$host"

atlas_timer_needs_restart=0
atlas_deploy_started=0
restart_atlas_timer() {
  exit_status=$?
  trap - EXIT
  if [[ "$atlas_timer_needs_restart" == "1" ]]; then
    if [[ "$maintenance" == "--maintenance" ]]; then
      if ! ssh "${ssh_args[@]}" atlas sudo systemctl stop nix-auto-sync-update.timer; then
        echo "failed to hold Atlas auto-update timer after maintenance deployment" >&2
        exit_status=1
      fi
      echo "Atlas maintenance: its auto-update timer remains stopped" >&2
    elif [[ "$atlas_deploy_started" == "1" && "$exit_status" != "0" ]]; then
      echo "Atlas deployment failed; its auto-update timer remains stopped" >&2
      echo "after fixing or reverting main, restart it with:" >&2
      echo "  ssh "${ssh_args[@]}" atlas sudo systemctl start nix-auto-sync-update.timer" >&2
    elif ! ssh "${ssh_args[@]}" atlas sudo systemctl start nix-auto-sync-update.timer; then
      echo "failed to restart Atlas auto-update timer" >&2
      exit_status=1
    fi
  fi
  exit "$exit_status"
}
trap restart_atlas_timer EXIT

if [[ "$host" == "atlas" ]]; then
  atlas_timer_needs_restart=1
  ssh "${ssh_args[@]}" atlas sudo systemctl stop nix-auto-sync-update.timer
  update_state="$(ssh "${ssh_args[@]}" atlas systemctl show --property=ActiveState --value nix-auto-sync-update.service)"
  if [[ "$update_state" != "inactive" ]]; then
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
  if [[ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]]; then
    echo "origin/main changed while building; Atlas was not deployed" >&2
    exit 1
  fi
fi

# Forge's full flake check has unrelated baseline failures. The three
# target checks above are the deployment gate.
if [[ "$host" == "atlas" ]]; then
  atlas_deploy_started=1
fi
nix run .#deploy -- "${deploy_args[@]}" ".#$host"
