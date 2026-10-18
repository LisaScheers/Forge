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
install -d -m 0700 "$checkpoint/synapse" "$checkpoint/bridge" "$checkpoint/runtime" "$checkpoint/verification"

# Copy immutable media first, keeping the service pause limited to the final
# delta and database dumps. --delete affects this generated staging copy only.
rsync -a --delete /var/lib/matrix-synapse/ "$checkpoint/synapse/"
restart_synapse=0
restart_bridge=0
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
printf '%s %s\n' "$restart_synapse" "$restart_bridge" > /run/matrix-coordinated-state
if (( restart_bridge )); then
  systemctl stop mautrix-discord.service
fi
if (( restart_synapse )); then
  systemctl stop matrix-synapse.service
fi
runuser -u postgres -- pg_dump -Fc --compress=lz4 matrix-synapse > "$checkpoint/synapse.dump.tmp"
runuser -u postgres -- pg_dump -Fc --compress=lz4 mautrix-discord > "$checkpoint/bridge.dump.tmp"
runuser -u postgres -- psql -XAt -d mautrix-discord > "$checkpoint/bridge-counts.json" <<'SQL'
SELECT json_build_object(
  'portals', (SELECT count(*) FROM portal), 'messages', (SELECT count(*) FROM message),
  'threads', (SELECT count(*) FROM thread), 'users', (SELECT count(*) FROM "user"));
SQL
rsync -a --delete /var/lib/matrix-synapse/ "$checkpoint/synapse/"
rsync -a --delete /var/lib/mautrix-discord/ "$checkpoint/bridge/"
install -m 0600 "$SYNAPSE_CONFIG" "$checkpoint/synapse-config.json"
for secret_name in matrix-registration-secret matrix-turn-secret discord-bridge-env; do
  install -m 0600 "/run/agenix/$secret_name" "$checkpoint/runtime/$secret_name"
done
for evidence_name in history-manifest.json sec-hive-pilot.json; do
  install -m 0600 "/var/lib/sec-hive-migration/$evidence_name" "$checkpoint/verification/$evidence_name"
done
mv "$checkpoint/synapse.dump.tmp" "$checkpoint/synapse.dump"
mv "$checkpoint/bridge.dump.tmp" "$checkpoint/bridge.dump"
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
