state_file=${MATRIX_BACKUP_STATE_FILE:-/run/matrix-coordinated-state}
if ! test -f "$state_file"; then
  exit 0
fi
test ! -e /var/lib/postgresql/.forge-maintenance
read -r restart_synapse restart_bridge restart_plural < "$state_file"
restart_plural=${restart_plural:-0}
[[ "$restart_synapse" =~ ^[01]$ && "$restart_bridge" =~ ^[01]$ && "$restart_plural" =~ ^[01]$ ]]
if (( restart_synapse )); then
  systemctl start matrix-synapse.service
fi
if (( restart_plural )); then
  systemctl start pluralmatrix.service
fi
if (( restart_bridge )); then
  systemctl start mautrix-discord.service
fi
rm "$state_file"
