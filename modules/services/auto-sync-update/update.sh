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
}
trap cleanup EXIT

# Keep the lock file so concurrent runs cannot lock different inodes.
exec 9>"$lock_path"
if ! flock -n 9; then
  echo "Another nix-auto-sync-update run is active; exiting."
  exit 0
fi

load_env() {
  local load_status=0
  if [ -f "$env_file" ]; then
    # Sourcing reports only the last command's status, so check the whole file
    # in a strict shell, then still load what it can so the failure is mailed.
    # The file is meant to hold assignments only, so reading it twice is safe.
    # shellcheck disable=SC2016 # $1 expands in the child shell.
    "$BASH" -euc '. "$1"' _ "$env_file" || load_status=$?
    # Unset references (say, a '$' in a password) must not abort the updater.
    set -a +u
    # shellcheck disable=SC1090
    . "$env_file" || load_status=$?
    set +a -u
  fi
  return "$load_status"
}

configure_git_auth() {
  git_args=(-c "safe.directory=$repo_path")

  if [ -n "${AUTO_SYNC_GIT_AUTH_HEADER:-}" ]; then
    git_args+=(-c "http.extraHeader=$AUTO_SYNC_GIT_AUTH_HEADER")
  fi

  if [ -n "${AUTO_SYNC_GIT_TOKEN:-}" ]; then
    askpass_file="$(mktemp)" || return $?
    chmod 700 "$askpass_file" || return $?
    cat > "$askpass_file" <<'EOF' || return $?
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
  # send_mail always runs in a pipeline subshell, so this trap is its own and
  # also removes the message if the unit is stopped mid-send.
  trap 'rm -f "$mail_file"' EXIT

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
    # A stalled server must not hold the update lock.
    --max-time 60
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

reboot_timer_pending() {
  [ "$custom_schedule_reboot" != "true" ] &&
    /run/current-system/sw/bin/systemctl is-active --quiet nix-auto-sync-update-reboot.timer
}

handle_required_reboot() {
  if ! reboot_required; then
    return 0
  fi
  # Leave a pending reboot alone so new commits cannot keep postponing it.
  if reboot_timer_pending; then
    echo "A reboot is already scheduled."
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

run_update() {
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
  if git "${git_args[@]}" show-ref --verify --quiet "refs/heads/$branch"; then
    git "${git_args[@]}" checkout "$branch"
  else
    git "${git_args[@]}" checkout --track -b "$branch" "origin/$branch"
  fi
  git "${git_args[@]}" merge --ff-only "origin/$branch"
  rev="$(git "${git_args[@]}" rev-parse HEAD)"
  # Local commits not on origin would otherwise be deployed unreviewed.
  if [ "$rev" != "$(git "${git_args[@]}" rev-parse "origin/$branch")" ]; then
    echo "Local $branch has commits that are not on origin/$branch; not rebuilding." >&2
    return 1
  fi

  # Build the committed tree, as deploy.sh does, so untracked files cannot
  # change the result.
  system_before="$(readlink -f /run/current-system 2>/dev/null || true)"
  # Lix fetches git+file inputs by running git, which does not see the -c
  # options above, so pass the safe.directory exception through the environment.
  GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.directory GIT_CONFIG_VALUE_0="$repo_path" \
    "${rebuild_cmd[@]}" --flake "$repo_url?rev=$rev#$flake_host"
  # The default scheduler is checked after every rebuild, so a kernel that
  # deploy.sh activated still gets its reboot. A custom scheduler cannot report
  # a pending reboot, so it runs only when this rebuild changed the system.
  if [ "$custom_schedule_reboot" != "true" ] ||
    [ "$(readlink -f /run/current-system 2>/dev/null || true)" != "$system_before" ]; then
    handle_required_reboot
  fi
}

# Load settings and Git credentials here rather than in the update subshell:
# the failure mail needs the SMTP settings, and the cleanup trap must see the
# askpass file. A broken environment file is reported like any other failure.
set +e
load_env 2>>"$log_file"
status=$?
set -e
if [ "$status" -ne 0 ]; then
  echo "Failed to load $env_file" >>"$log_file"
fi
if [ "$status" -eq 0 ]; then
  set +e
  configure_git_auth 2>>"$log_file"
  status=$?
  set -e
fi
if [ "$status" -ne 0 ]; then
  cat "$log_file" >&2
  send_failure_mail "$status"
  exit "$status"
fi

# Run the update in a subshell outside any condition: an `if` around the
# call would disable errexit inside it and hide failed steps.
set +e
(
  set -e
  run_update
) 2>&1 | tee -a "$log_file"
# A pipeline ends only after tee has written the whole log for the mail below.
status=${PIPESTATUS[0]}
set -e
if [ "$status" -ne 0 ]; then
  send_failure_mail "$status"
fi
exit "$status"
