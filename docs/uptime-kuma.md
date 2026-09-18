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
- Successful Atlas and Nook automatic update jobs also report through
  `ExecStartPost`. Their monitors allow two hours for builds and updates.
- Reporting failures do not fail backup or update jobs. Missing reports are
  detected by Kuma's push deadlines.

The 12 push monitors were created paused pending the first deployment. After
the configuration reaches `origin/main` and rolls out, resume them in Kuma,
start `uptime-kuma-probes.service` on both hosts, and verify the results.
Backup and update completion checks receive their first reports after those
jobs finish successfully; do not send synthetic success reports.

The probe systemd units and both host configurations were evaluated/built
without activating a new system configuration.
