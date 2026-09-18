# Uptime Kuma

Atlas runs Uptime Kuma at https://uptime.bylisa.dev. Monitors are stored in its
SQLite database under `/var/lib/uptime-kuma`, and are managed through the UI.
The dashboard groups checks under Atlas, Nook, and Mail.

Network and local Atlas system-service monitors run directly in Kuma. Network
checks normally run every 60 seconds with two retries. Mail SMTP monitors verify
the connection and STARTTLS/SMTPS negotiation without sending messages. IMAP,
POP3, ManageSieve, LDAPS, and TURN TCP monitors check listeners, not login or
end-to-end delivery/relay functionality.

## Private probes

`flake-parts/hosts/uptime-kuma-probes.nix` defines a local systemd timer on Atlas
and Nook. The timer reports to push monitors without exposing private services.
Each host's push tokens are encrypted in its `uptime-kuma-probes.age` secret.

- Atlas runs a PostgreSQL `SELECT 1` over the local socket as `postgres`.
- Nook checks Loki, Mimir, and Tempo readiness; Sonarr, Radarr, and Prowlarr
  HTTP responses; and the Squid and Dante TCP listeners.
- Local probes run 60 seconds after their previous run finishes. Kuma expects
  a report within 180 seconds.
- A successful Forgejo PostgreSQL backup reports through `ExecStartPost`.
  Its monitor expects completion within 26 hours.
- Atlas's automatic update job also reports through `ExecStartPost`. Its
  monitor allows two hours for builds and updates. Nook has no scheduled
  auto-update job, so its completion monitor is paused as not applicable.
- Reporting failures do not fail backup or update jobs. Missing reports are
  detected by Kuma's push deadlines.

The 11 applicable push monitors are enabled following deployment. When
restoring this setup, deploy from `origin/main`, resume those monitors in Kuma,
start `uptime-kuma-probes.service` on both hosts, and verify the results.
Backup and update completion checks receive their first reports after those
jobs finish successfully; do not send synthetic success reports.

The probe systemd units and both host configurations were evaluated/built
without activating a new system configuration.
