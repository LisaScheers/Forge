# Uptime Kuma

Atlas runs Uptime Kuma at https://uptime.bylisa.dev. Monitors are stored in its
SQLite database under `/var/lib/uptime-kuma`, and are managed through the UI.
The dashboard groups checks under Atlas, Nook, and Mail.

Network and local Atlas system-service monitors run directly in Kuma. Network
checks normally run every 60 seconds with two retries. Mail SMTP monitors verify
the connection and STARTTLS/SMTPS negotiation without sending messages. IMAP,
POP3, ManageSieve, LDAPS, and TURN TCP monitors check listeners, not login or
end-to-end delivery/relay functionality.

Atlas's Minecraft system-service monitor checks `minecraft.service`, the socket
proxy to Nook. The old local `atm10-8-0.service` is intentionally masked; the
game server runs on Nook. The separate game query through Atlas's loopback
port 25565 checks the proxy and backend together.

## Private probes

`modules/services/monitoring/probes.nix` defines a local systemd timer on Atlas
and Nook. The timer reports to push monitors without exposing private services.
Each host's push tokens are encrypted in its `uptime-kuma-probes.age` secret.

- Atlas runs a PostgreSQL `SELECT 1` over the local socket as `postgres`.
- Nook checks Sonarr, Radarr, and Prowlarr HTTP responses, and the Squid and
  Dante TCP listeners.
- Local probes run 60 seconds after their previous run finishes. Kuma expects
  a report within 180 seconds.
- A successful full-cluster PostgreSQL backup reports through `ExecStartPost`.
  Its monitor expects completion within 26 hours.
- Atlas's automatic update job also reports through `ExecStartPost`. Its
  monitor allows two hours for builds and updates. Nook has no scheduled
  auto-update job, so its completion monitor is paused as not applicable.
- Reporting failures do not fail backup or update jobs. Missing reports are
  detected by Kuma's push deadlines.

The eight applicable push monitors are enabled following deployment. When
restoring this setup, deploy from `origin/main`, resume those monitors in Kuma,
start `uptime-kuma-probes.service` on both hosts, and verify the results.
Backup and update completion checks receive their first reports after those
jobs finish successfully; do not send synthetic success reports.

The metrics, logs, traces, and profiling stack has been retired. Its old Kuma
checks are paused, while PostgreSQL, backup, update, media, and proxy checks stay
enabled. Existing monitoring data is retained on Nook.

Mail's separate legacy Alloy container was disabled on 2026-10-17 after repeated
host OOM kills and connectivity failures. `mailcow-alloy` is stopped with Docker
restart policy `no`. On Mail, `/opt/mailcow-observability/docker-compose.yml`
also assigns Alloy the `disabled` profile and `restart: "no"`, so a normal
Compose start excludes it. The original file is retained beside it as
`docker-compose.yml.before-disable-alloy-20261017`. Mail filtering stays enabled.
