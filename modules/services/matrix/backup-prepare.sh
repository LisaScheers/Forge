umask 077
checkpoint=/var/backup/matrix-coordinated
install -d -m 0700 "$checkpoint"
exec 9>/run/lock/matrix-coordinated.lock
flock -n 9
# Share the updater's lock for the short checkpoint phase, not the upload.
exec 8>/run/nix-auto-sync-update.lock
flock -n 8
test ! -e /var/lib/postgresql/.forge-maintenance
rm -f "$checkpoint/COMPLETE"
rm -f "$checkpoint/verification/post-wave-reaction-changes.json" "$checkpoint/verification/post-wave-snapshot-boundary.json"
install -d -m 0700 "$checkpoint/synapse" "$checkpoint/bridge" "$checkpoint/runtime" "$checkpoint/verification"

# A one-run capture can require the same audit before and after the pause.
# Resolve once, preserving argv[0] for multicall executables, without parsing
# command strings. Only root-controlled targets and ancestors are accepted.
validated_hook() {
  local resolved current permissions
  [[ "$1" == /* && -f "$1" && -x "$1" ]] || return 1
  resolved=$(readlink -f -- "$1") || return 1
  [[ "$resolved" == /* ]] || return 1
  current=$resolved
  while true; do
    [[ $(stat -c %u -- "$current") == 0 ]] || return 1
    permissions=$(stat -c %a -- "$current") || return 1
    if (( (8#$permissions & 022) != 0 )); then
      # Sticky root-owned directories (including /nix/store) cannot replace
      # the root-owned child already checked on the preceding iteration.
      [[ -d "$current" ]] && (( (8#$permissions & 01000) != 0 )) || return 1
    fi
    [[ "$current" != / ]] || break
    current=$(dirname -- "$current") || return 1
  done
  printf '%s\n' "$resolved"
}
warm_hook=
cold_hook=
if [[ -n "${MATRIX_BACKUP_WARM_HOOK:-}" || -n "${MATRIX_BACKUP_COLD_HOOK:-}" ]]; then
  test -n "${MATRIX_BACKUP_WARM_HOOK:-}"
  test -n "${MATRIX_BACKUP_COLD_HOOK:-}"
  warm_hook=$(validated_hook "$MATRIX_BACKUP_WARM_HOOK")
  cold_hook=$(validated_hook "$MATRIX_BACKUP_COLD_HOOK")
fi
export MATRIX_BACKUP_CHECKPOINT="$checkpoint"

copy_synapse() {
  rsync -a --delete --exclude=/media_store/ /var/lib/matrix-synapse/ "$checkpoint/synapse/"
  install -d -m 0700 "$checkpoint/synapse/media_store"
  if [[ -n "${MEDIA_RSYNC_SSH:-}" ]]; then
    # The local recovery copy stays independent of Nook's live media disk.
    # Fetch its file list through restricted rsync, avoiding per-file NFS RTTs.
    "$MEDIA_COPY_COMMAND" matrix-backup:. "$checkpoint/synapse/media_store"
  else
    "$MEDIA_COPY_COMMAND" /var/lib/matrix-synapse/media_store "$checkpoint/synapse/media_store"
  fi
}

# Copy media first; only the final delta and database dumps require a pause.
# --delete affects the generated local staging copy, never Nook's live store.
copy_synapse
cat > "$checkpoint/media-backup-policy.json" <<'JSON'
{"version":1,"omitted_generated_media_directories":["local_thumbnails","remote_thumbnail","url_cache_thumbnails"],"original_media":"preserved","thumbnail_database_metadata":"preserved"}
JSON
if [[ -n "$warm_hook" ]]; then
  (exec -a "$MATRIX_BACKUP_WARM_HOOK" "$warm_hook")
fi
restart_synapse=0
restart_bridge=0
restart_plural=0
resume_services() {
  result=$?
  trap - EXIT
  "$RESUME_COMMAND" || result=1
  exit "$result"
}
trap resume_services EXIT
trap 'exit 143' TERM
trap 'exit 130' INT
if systemctl is-active --quiet mautrix-discord.service; then
  restart_bridge=1
fi
if systemctl is-active --quiet matrix-synapse.service; then
  restart_synapse=1
fi
if [[ "${PLURAL_ENABLED:-0}" == 1 ]] && systemctl is-active --quiet pluralmatrix.service; then
  restart_plural=1
fi
printf '%s %s %s\n' "$restart_synapse" "$restart_bridge" "$restart_plural" > /run/matrix-coordinated-state
if (( restart_plural )); then
  systemctl stop pluralmatrix.service
fi
if (( restart_bridge )); then
  systemctl stop mautrix-discord.service
fi
if (( restart_synapse )); then
  systemctl stop matrix-synapse.service
fi
for _ in $(seq 1 30); do
  connections=$(runuser -u postgres -- psql -XAt -v ON_ERROR_STOP=1 -d postgres -c "SELECT count(*) FROM pg_stat_activity WHERE usename IN ('matrix-synapse','mautrix-discord','pluralmatrix')")
  if [[ "$connections" == 0 ]]; then
    break
  fi
  sleep 1
done
test "$connections" == 0
if [[ -n "$cold_hook" ]]; then
  (exec -a "$MATRIX_BACKUP_COLD_HOOK" "$cold_hook")
fi
# COMPLETE was removed before updating this generated staging directory.
# Direct writes avoid a second database-sized copy; only the verified full
# checksum manifest and a new COMPLETE mark the checkpoint coherent again.
runuser -u postgres -- pg_dump -Fc --compress=lz4 matrix-synapse > "$checkpoint/synapse.dump"
runuser -u postgres -- pg_dump -Fc --compress=lz4 mautrix-discord > "$checkpoint/bridge.dump"
if [[ "${PLURAL_ENABLED:-0}" == 1 ]]; then
  runuser -u postgres -- pg_dump -Fc --compress=lz4 pluralmatrix > "$checkpoint/plural.dump"
  runuser -u postgres -- psql -XAt -v ON_ERROR_STOP=1 -d pluralmatrix > "$checkpoint/plural-counts.json" <<'SQL'
SELECT json_build_object('systems', (SELECT count(*) FROM "System"), 'members', (SELECT count(*) FROM "Member"),
  'switches', (SELECT count(*) FROM "Switch"), 'journal', (SELECT count(*) FROM "InboundEvent"));
SQL
  install -d -m 0700 "$checkpoint/plural" "$checkpoint/plural-registration"
  rsync -a --delete /var/lib/pluralmatrix/ "$checkpoint/plural/"
  rsync -a --delete /var/lib/pluralmatrix-registration/ "$checkpoint/plural-registration/"
  install -m 0600 "$PLURAL_CONFIG" "$checkpoint/plural-config.json"
  runuser -u postgres -- psql -XAt -v ON_ERROR_STOP=1 -d mautrix-discord -c 'SELECT count(*) FROM sec_hive_plural_pending' > "$checkpoint/plural-bridge-pending-count"
fi
printf '%s\n' "${PLURAL_ENABLED:-0}" > "$checkpoint/plural-enabled"
runuser -u postgres -- psql -XAt -v ON_ERROR_STOP=1 -d mautrix-discord > "$checkpoint/bridge-counts.json" <<'SQL'
SELECT json_build_object(
  'portals', (SELECT count(*) FROM portal), 'messages', (SELECT count(*) FROM message),
  'threads', (SELECT count(*) FROM thread), 'users', (SELECT count(*) FROM "user"));
SQL
copy_synapse
rsync -a --delete /var/lib/mautrix-discord/ "$checkpoint/bridge/"
install -m 0600 "$SYNAPSE_CONFIG" "$checkpoint/synapse-config.json"
for secret_name in matrix-registration-secret matrix-turn-secret discord-bridge-env; do
  install -m 0600 "/run/agenix/$secret_name" "$checkpoint/runtime/$secret_name"
done
for evidence_name in history-manifest.json sec-hive-pilot.json; do
  install -m 0600 "/var/lib/sec-hive-migration/$evidence_name" "$checkpoint/verification/$evidence_name"
done
readlink -f /run/current-system > "$checkpoint/system-generation"
date --utc --iso-8601=seconds > "$checkpoint/captured-at"

# Resume before hashing and uploading: the frozen staging directory is the
# backup source, so network transfer never extends the homeserver outage.
"$RESUME_COMMAND"
cd "$checkpoint"
find . -type f ! -name SHA256SUMS ! -name COMPLETE -print0 | sort -z | xargs -0 sha256sum > /run/matrix-coordinated-checksums
mv /run/matrix-coordinated-checksums SHA256SUMS
sha256sum --check --status SHA256SUMS
date --utc --iso-8601=seconds > COMPLETE
