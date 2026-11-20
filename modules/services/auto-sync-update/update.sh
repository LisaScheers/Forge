# shellcheck shell=bash
# shellcheck disable=SC2154 # Configured values come from the prelude in default.nix.
# Pull the repository, switch the host, and schedule a reboot when the new
# system changes the kernel, initrd or modules.
env_file="${AUTO_SYNC_ENV_FILE:-$default_env_file}"
log_file="$(mktemp)"

# shellcheck disable=SC2329
cleanup() {
  rm -f "$log_file"
  if [ -n "${askpass_file:-}" ]; then
    rm -f "$askpass_file"
  fi
  if [ -n "${mail_file:-}" ]; then
    rm -f "$mail_file"
  fi
}
trap cleanup EXIT

# Keep the lock file so concurrent runs cannot lock different inodes.
exec 9>"$lock_path"
if ! flock -n 9; then
  echo "Another nix-auto-sync-update run is active; exiting."
  exit 0
fi

load_env() {
  if [ -f "$env_file" ]; then
    set -a
    # shellcheck disable=SC1090
    . "$env_file"
    set +a
  fi
}

configure_git_auth() {
  git_args=(-c "safe.directory=$repo_path")

  if [ -n "${AUTO_SYNC_GIT_AUTH_HEADER:-}" ]; then
    git_args+=(-c "http.extraHeader=$AUTO_SYNC_GIT_AUTH_HEADER")
  fi

  if [ -n "${AUTO_SYNC_GIT_TOKEN:-}" ]; then
    askpass_file="$(mktemp)"
    chmod 700 "$askpass_file"
    cat > "$askpass_file" <<'EOF'
#!/bin/sh
case "$1" in
  *Username*) printf '%s\n' "${AUTO_SYNC_GIT_USERNAME:-x-access-token}" ;;
  *Password*) printf '%s\n' "${AUTO_SYNC_GIT_TOKEN}" ;;
  *) printf '\n' ;;
esac
EOF
    export GIT_ASKPASS="$askpass_file"
    export GIT_TERMINAL_PROMPT=0
  fi
}

send_mail() {
  subject="$1"
  if [ -z "${AUTO_SYNC_SMTP_URL:-}" ]; then
    echo "AUTO_SYNC_SMTP_URL is not set; cannot send email: $subject" >&2
    # Drain the body so the writer does not fail with a broken pipe.
    cat >/dev/null
    return 0
  fi

  mail_from="${AUTO_SYNC_SMTP_FROM:-nix-auto-sync-update@$mail_host}"
  mail_to="${AUTO_SYNC_SMTP_TO:-$email_to}"
  mail_file="$(mktemp)"

  {
    printf 'From: %s\r\n' "$mail_from"
    printf 'To: %s\r\n' "$mail_to"
    printf 'Subject: %s\r\n' "$subject"
    printf 'Content-Type: text/plain; charset=UTF-8\r\n'
    printf '\r\n'
    cat
  } > "$mail_file"

  curl_args=(
    --fail
    --show-error
    --silent
    --url "$AUTO_SYNC_SMTP_URL"
    --mail-from "$mail_from"
    --mail-rcpt "$mail_to"
    --upload-file "$mail_file"
  )

  if [ "${AUTO_SYNC_SMTP_REQUIRE_TLS:-1}" != "0" ]; then
    curl_args+=(--ssl-reqd)
  fi

  if [ -n "${AUTO_SYNC_SMTP_USERNAME:-}" ] || [ -n "${AUTO_SYNC_SMTP_PASSWORD:-}" ]; then
    curl_args+=(--user "${AUTO_SYNC_SMTP_USERNAME:-}:${AUTO_SYNC_SMTP_PASSWORD:-}")
  fi

  if ! curl "${curl_args[@]}"; then
    echo "Failed to send email: $subject" >&2
  fi
}

send_failure_mail() {
  status="$1"

  {
    printf 'nix-auto-sync-update failed on %s with exit status %s.\n\n' "$flake_host" "$status"
    printf 'Repository: %s\n' "$repo_path"
    printf 'Branch: %s\n\n' "$branch"
    printf 'Captured output:\n'
    cat "$log_file"
  } | send_mail "[watchdog] nix auto-sync-update failed on $flake_host"
}

reboot_required() {
  if [ "${AUTO_SYNC_FORCE_REBOOT_REQUIRED:-0}" = "1" ]; then
    return 0
  fi

  if [ "$custom_reboot_required" = "true" ]; then
    "${reboot_required_cmd[@]}"
    return "$?"
  fi

  if [ ! -e /run/current-system ] || [ ! -e /run/booted-system ]; then
    return 1
  fi

  for artifact in kernel initrd kernel-modules; do
    if [ ! -e "/run/current-system/$artifact" ]; then
      continue
    fi

    current_artifact="$(readlink -f "/run/current-system/$artifact")"
    booted_artifact="$(readlink -f "/run/booted-system/$artifact" 2>/dev/null || true)"
    if [ "$current_artifact" != "$booted_artifact" ]; then
      echo "Reboot required: $artifact changed from $booted_artifact to $current_artifact."
      return 0
    fi
  done

  return 1
}

schedule_reboot() {
  if [ "$custom_schedule_reboot" != "true" ]; then
    /run/current-system/sw/bin/systemctl stop nix-auto-sync-update-reboot.timer nix-auto-sync-update-reboot.service 2>/dev/null || true
    /run/current-system/sw/bin/systemctl reset-failed nix-auto-sync-update-reboot.timer nix-auto-sync-update-reboot.service 2>/dev/null || true
  fi

  "${schedule_reboot_cmd[@]}"
}

handle_required_reboot() {
  if ! reboot_required; then
    return 0
  fi

  schedule_output="$(schedule_reboot 2>&1)"
  printf '%s\n' "$schedule_output"

  {
    printf 'nix-auto-sync-update applied updates on %s and detected that a reboot is required.\n\n' "$flake_host"
    printf 'Repository: %s\n' "$repo_path"
    printf 'Branch: %s\n' "$branch"
    printf 'The reboot has been scheduled %s seconds after the update.\n\n' "$reboot_delay_seconds"
    printf 'Scheduler output:\n%s\n' "$schedule_output"
  } | send_mail "[watchdog] reboot required on $flake_host"
}

reboot_timer_pending() {
  [ "$custom_schedule_reboot" != "true" ] &&
    /run/current-system/sw/bin/systemctl is-active --quiet nix-auto-sync-update-reboot.timer
}

run_update() {
  configure_git_auth

  if [ ! -d "$repo_path/.git" ]; then
    if [ -z "${AUTO_SYNC_GIT_REPOSITORY_URL:-}" ]; then
      echo "$repo_path is not a git checkout and AUTO_SYNC_GIT_REPOSITORY_URL is not set." >&2
      return 1
    fi

    mkdir -p "$(dirname "$repo_path")"
    git "${git_args[@]}" clone --branch "$branch" "$AUTO_SYNC_GIT_REPOSITORY_URL" "$repo_path"
  fi

  cd "$repo_path"
  git "${git_args[@]}" fetch --prune origin "$branch"
  if git show-ref --verify --quiet "refs/heads/$branch"; then
    git "${git_args[@]}" checkout "$branch"
  else
    git "${git_args[@]}" checkout --track -b "$branch" "origin/$branch"
  fi
  git "${git_args[@]}" merge --ff-only "origin/$branch"

  # Check for a reboot whenever this rebuild changed the system (which also
  # covers a retry after an earlier failed build), and retry scheduling when a
  # reboot is still needed but no default reboot timer is pending.
  system_before="$(readlink -f /run/current-system 2>/dev/null || true)"
  "${rebuild_cmd[@]}" --flake "path:$repo_path#$flake_host"
  if [ "$(readlink -f /run/current-system 2>/dev/null || true)" != "$system_before" ]; then
    handle_required_reboot
  elif [ "$custom_schedule_reboot" != "true" ] && ! reboot_timer_pending; then
    handle_required_reboot
  fi
}

# The failure mail below needs the SMTP settings too, so load them here.
load_env

# Run the update in a subshell outside any condition: an `if` around the
# call would disable errexit inside it and hide failed steps.
set +e
(
  set -e
  run_update
) > >(tee -a "$log_file") 2>&1
status=$?
set -e
if [ "$status" -ne 0 ]; then
  send_failure_mail "$status"
fi
exit "$status"
