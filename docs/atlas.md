# Atlas

Atlas deploys with the same `just deploy` commands as Nook (see the
[README](../README.md#deployment)) and also updates itself from `main` through
`nix-auto-sync-update`.

## Deploying

The Atlas recipe refuses dirty or off-main revisions, aborts when an auto-update
or scheduled reboot is active, and pauses `nix-auto-sync-update.timer` while
deploy-rs runs. It restarts the timer after a successful deployment or a
preflight abort, unless the timer was already stopped before the deploy (a timer
systemd marked failed is restarted). If deploy-rs itself fails, the recipe stops
the timer again so it cannot retry the same bad `main` revision, and later
deploys keep it stopped too; once that stop succeeds the recipe prints the
command that starts it again, and if the stop fails it says so and the timer may
run. A stopped timer starts again when Atlas boots, so a hold that must survive
a reboot needs the maintenance marker below.

After a kernel change the updater arms a reboot up to 12 hours later, which
blocks deploys until then. To deploy sooner, reboot Atlas or cancel the pending
reboot with `ssh atlas sudo systemctl stop nix-auto-sync-update-reboot.timer`
and deploy before the next updater run, which re-arms it if the activated
kernel, initrd or modules still differ from the booted generation.

deploy-rs connects to Atlas as `lisa`, which `modules/hosts/atlas/system.nix`
makes a trusted Nix user. On a freshly installed Atlas, let its auto-updater
apply `main` once, then confirm before the first deploy-rs run:

```sh
ssh atlas 'nix config show trusted-users'
```

## Auto-updater

The updater's checkout is `/etc/nix-darwin` on Atlas too; the name predates
NixOS hosts, and moving the live checkout is not worth a migration.

systemd loads the Atlas updater's `/run/agenix/auto-sync-update-env`
(`EnvironmentFile=`), so it holds plain `KEY=value` lines and never runs as
shell code: `AUTO_SYNC_SMTP_URL`, `AUTO_SYNC_SMTP_USERNAME`,
`AUTO_SYNC_SMTP_PASSWORD`, `AUTO_SYNC_SMTP_FROM`, `AUTO_SYNC_SMTP_TO` and
`AUTO_SYNC_SMTP_REQUIRE_TLS` for failure mail, and `AUTO_SYNC_GIT_TOKEN`,
`AUTO_SYNC_GIT_USERNAME`, `AUTO_SYNC_GIT_AUTH_HEADER` or
`AUTO_SYNC_GIT_REPOSITORY_URL` for Git access. Use systemd's format: quotes are
stripped, and `export` and `$` expansion are not supported. systemd skips lines
that are not assignments, and when the file exists but provides no SMTP URL, any
run that needs to send mail fails visibly (and a failed rebuild keeps its own
exit status). The updater only fast-forwards to `origin/main`: if the Atlas
checkout has local commits, every run fails and mails until the checkout is
reset to `origin/main`. The journal has the same reason even if mail fails. Keep
the commits on a branch before resetting:

```sh
# Needs passwordless sudo on Atlas, as deploy-rs already does.
ssh atlas sudo journalctl -u nix-auto-sync-update -n 50
# Saves the local commits to a branch, then resets. Nothing is changed if the
# checkout has uncommitted changes or the branch cannot be created.
ssh atlas 'git() { sudo git -c safe.directory=/etc/nix-darwin -C /etc/nix-darwin "$@"; }
  changes="$(git status --porcelain)" || exit 1
  if [ -n "$changes" ]; then
    echo "Uncommitted changes; handle them first." >&2
    exit 1
  else
    git branch "atlas-local-$(date +%Y%m%d-%H%M%S)" && git reset --hard origin/main
  fi'
```

## Maintenance and PostgreSQL

For an approved database maintenance window, first create the root-owned marker
that prevents updater runs, including across reboots, then apply Atlas with its
updater timer left stopped:

```sh
ssh atlas sudo touch /var/lib/postgresql/.forge-maintenance
just deploy-maintenance
```

Keep the marker and timer hold until migration and recovery checks pass; then
remove the marker and restart `nix-auto-sync-update.timer` explicitly.

Atlas's PostgreSQL major and data directory are pinned in
`modules/services/postgresql/atlas.nix`. Its scheduled `pg_dumpall` backup covers
cluster roles and every database except `matrix-synapse`, `mautrix-discord` and
`pluralmatrix`, which are intentionally unbacked
([Matrix after SEC-Hive](sec-hive-matrix.md)). The existing Uptime Kuma probe
reports completion.

Nook copies that dump off Atlas every day at 04:30 into
`/srv/disks/western-digital-hdd/backups/atlas-postgresql/all-<date>.sql.zstd`,
checks it with `zstd --test` before keeping it, and prunes copies older than 14
days (`modules/services/postgresql/offsite.nix`). It logs in as `postgres` with
a key that Atlas restricts to printing the dump; the private half is
`secrets/nook/atlas-backup-pull-key.age`. A failed copy fails
`postgresql-backup-pull.service` on Nook and leaves the previous copies alone.

Atlas uses PostgreSQL 18 at `/var/lib/postgresql/18`. Startup requires its
`PG_VERSION` and `.forge-upgrade-complete` marker; create the marker only after a
successful `pg_upgrade` or a verified full restore. Keep the PostgreSQL 16
directory and its system generation for recovery. Returning to it after new
writes requires reconciling those writes or restoring a current backup.

## Rebuilding Atlas

Take the newest copy from Nook (above), or copy Atlas's latest dump if Atlas is
still reachable. Then:

1. Restore the old `/etc/ssh/ssh_host_ed25519_key` pair, which agenix decrypts
   with. With a new key instead, put its public half in
   `modules/security/agenix/pubkeys.nix` (`hosts.atlas`) and run
   `just secret-rekey` before deploying; otherwise no Atlas secret decrypts.
2. Before the Forge configuration first boots or activates, create the
   maintenance marker, `/var/lib/postgresql/.forge-maintenance`, so the updater
   stays held throughout.
3. PostgreSQL refuses to start until
   `/var/lib/postgresql/18/.forge-upgrade-complete` exists. Copy the newest
   dump from Nook to `/root/all.sql.zstd` and restore it with the script that
   `modules/services/postgresql/tests.nix` tests:

   ```sh
   sudo forge-postgresql-restore /root/all.sql.zstd
   ```

   It refuses an existing cluster, restores into a new one through a private
   socket with TCP off, lists the restored databases, and creates the marker
   only after the restore and a clean shutdown succeed. It bootstraps with a
   uniquely named role, left unable to log in, so a later dump restores too.

   The Matrix databases are not in the dump; see
   [Matrix after SEC-Hive](sec-hive-matrix.md).
4. Start PostgreSQL, check `systemctl --failed` and the Uptime Kuma probes, then
   release the hold as described under
   [Maintenance and PostgreSQL](#maintenance-and-postgresql).
