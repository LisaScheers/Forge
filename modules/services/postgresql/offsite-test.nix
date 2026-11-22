{
  config,
  lib,
  withSystem,
  ...
}: let
  features = config.nixos;
  hosts = config.flake.nixosConfigurations;
  # Production order, in one time zone: the copy follows Atlas's dump.
  dumpAt = lib.toList hosts.atlas.config.services.postgresqlBackup.startAt;
  copyAt = hosts.nook.config.services.postgresqlBackupPull.startAt;
in {
  perSystem = {pkgs, ...}: {
    checks.postgresql-backup-schedule = let
      inOrder = dumpAt == ["*-*-* 03:00:00 UTC"] && copyAt == "*-*-* 04:30:00 UTC";
    in
      assert lib.assertMsg inOrder "Atlas's dump must run at 03:00 UTC and Nook's copy at 04:30 UTC; got ${toString dumpAt} and ${copyAt}";
        pkgs.runCommand "postgresql-backup-schedule" {} ''touch "$out"'';
  };

  flake.checks.x86_64-linux.postgresql-backup-pull = withSystem "x86_64-linux" ({pkgs, ...}: let
    # Throwaway keys for the test only: the puller's key and the source's host key.
    keys = pkgs.runCommand "postgresql-backup-pull-test-keys" {nativeBuildInputs = [pkgs.openssh];} ''
      mkdir "$out"
      ssh-keygen -q -t ed25519 -N "" -f "$out/client"
      ssh-keygen -q -t ed25519 -N "" -f "$out/host"
    '';
    hostKey = builtins.readFile "${keys}/host.pub";
    # A small cluster dump, as Atlas's nightly backup would produce.
    dump = pkgs.runCommand "postgresql-restore-test-dump.sql.zstd" {nativeBuildInputs = [pkgs.postgresql_18 pkgs.zstd];} ''
      export PGHOST="$PWD" PGPORT=6545 PGUSER=postgres
      initdb -U postgres -D cluster >/dev/null
      pg_ctl -D cluster -l log -o "-c listen_addresses= -c unix_socket_directories=$PWD -p 6545" -w start >/dev/null
      psql -X -q -v ON_ERROR_STOP=1 -c "CREATE ROLE application LOGIN" -c "CREATE DATABASE application OWNER application"
      psql -X -q -v ON_ERROR_STOP=1 -d application -c "CREATE TABLE kept (value text)" -c "INSERT INTO kept VALUES ('restored')"
      pg_dumpall | zstd -q -o "$out"
      pg_ctl -D cluster -m fast -w stop >/dev/null
    '';
  in
    pkgs.testers.runNixOSTest {
      name = "postgresql-backup-pull";
      nodes.source = {lib, ...}: {
        imports = [features.postgresql-backup-reader];
        services.postgresqlBackupReader = {
          authorizedKey = lib.removeSuffix "\n" (builtins.readFile "${keys}/client.pub");
          dump = "/var/backup/postgresql/all.sql.zstd";
        };
        users.users.postgres = {
          isSystemUser = true;
          group = "postgres";
          useDefaultShell = true;
          home = "/var/lib/postgresql";
          createHome = true;
        };
        users.groups.postgres = {};
        services.openssh = {
          enable = true;
          hostKeys = [];
          extraConfig = "HostKey /etc/ssh/test_host_key";
        };
        environment.etc."ssh/test_host_key" = {
          source = "${keys}/host";
          mode = "0600";
        };
        environment.systemPackages = [pkgs.zstd];
        system.stateVersion = "26.05";
      };
      nodes.puller = {
        imports = [features.postgresql-backup-pull];
        services.postgresqlBackupPull = {
          host = "source";
          hostKey = builtins.head (builtins.match "([^ ]+ [^ ]+).*" hostKey);
          keyFile = "/etc/backup-pull-key";
          destination = "/srv/backups/atlas-postgresql";
          keepDays = 3;
        };
        # Nook's clock, so copies must be dated in UTC regardless.
        time.timeZone = "Europe/Brussels";
        # Like Nook's data disk: mounted on demand, after boot-time setup ran.
        virtualisation.fileSystems."/srv/backups" = {
          device = "tmpfs";
          fsType = "tmpfs";
          options = ["noauto"];
        };
        environment.etc."backup-pull-key" = {
          source = "${keys}/client";
          mode = "0600";
        };
        environment.systemPackages = [pkgs.zstd];
        system.stateVersion = "26.05";
      };
      # A rebuilt host: the real start guard and restore command, run as root.
      nodes.rebuilt = {pkgs, ...}: {
        imports = [features.postgresql-restore-guard];
        services.postgresql = {
          enable = true;
          package = pkgs.postgresql_18;
          dataDir = "/var/lib/postgresql/18";
        };
        forge.postgresqlRestore.expectedDatabases = ["application"];
        system.stateVersion = "26.05";
      };
      testScript = ''
        start_all()
        source.wait_for_unit("sshd.service")
        source.succeed("mkdir -p /var/backup/postgresql && echo 'CREATE TABLE restored ();' | zstd -q -o /var/backup/postgresql/all.sql.zstd && chown -R postgres /var/backup/postgresql && chmod 0600 /var/backup/postgresql/all.sql.zstd")

        with subtest("the dump is copied, verified and dated"):
            puller.succeed("systemctl start postgresql-backup-pull.service")
            assert puller.succeed("zstd -dc /srv/backups/atlas-postgresql/all-$(date -u +%F).sql.zstd").strip() == "CREATE TABLE restored ();"

        with subtest("the key can only read the dump"):
            puller.succeed("install -m 0600 /etc/backup-pull-key /root/key")
            ssh = "ssh -i /root/key -o BatchMode=yes -o StrictHostKeyChecking=no postgres@source"
            # Whatever command is asked for, the forced command prints the dump.
            assert puller.succeed(f"timeout 30 {ssh} id | zstd -dc").strip() == "CREATE TABLE restored ();"
            # restrict refuses forwarding; a remote forward is refused at login.
            status, refused = puller.execute(f"timeout 30 {ssh} -N -R 9999:localhost:22 -o ExitOnForwardFailure=yes 2>&1")
            assert status != 0 and "forwarding failed" in refused, refused

        with subtest("a corrupt dump never replaces a good copy"):
            source.succeed("printf 'not zstd' > /var/backup/postgresql/all.sql.zstd")
            puller.fail("systemctl start postgresql-backup-pull.service")
            assert puller.succeed("zstd -dc /srv/backups/atlas-postgresql/all-$(date -u +%F).sql.zstd").strip() == "CREATE TABLE restored ();"
            puller.fail("ls /srv/backups/atlas-postgresql/*.part")

        with subtest("yesterday's dump is refused, so the copy fails and keeps the last good one"):
            # A missed nightly run: the dump is from an earlier UTC day.
            source.succeed("echo 'SELECT 2;' | zstd -q -f -o /var/backup/postgresql/all.sql.zstd && chown postgres /var/backup/postgresql/all.sql.zstd && touch -d '24 hours 45 minutes ago' /var/backup/postgresql/all.sql.zstd")
            puller.succeed("cp /srv/backups/atlas-postgresql/all-$(date -u +%F).sql.zstd /root/good.sql.zstd")
            puller.fail("systemctl start postgresql-backup-pull.service")
            puller.succeed("journalctl -u postgresql-backup-pull.service | grep -q 'not today'")
            puller.succeed("cmp /root/good.sql.zstd /srv/backups/atlas-postgresql/all-$(date -u +%F).sql.zstd")
            source.succeed("touch /var/backup/postgresql/all.sql.zstd")

        with subtest("copies older than keepDays are pruned"):
            source.succeed("echo 'SELECT 1;' | zstd -q -f -o /var/backup/postgresql/all.sql.zstd")
            # keepDays = 3: the copy dated three days back stays, four days back
            # goes, and a hand-named file is never pruned.
            puller.succeed("cd /srv/backups/atlas-postgresql && for age in 3 4; do cp all-$(date -u +%F).sql.zstd all-$(date -u -d \"$age days ago\" +%F).sql.zstd; done && cp all-$(date -u +%F).sql.zstd all-before-upgrade.sql.zstd")
            puller.succeed("systemctl start postgresql-backup-pull.service")
            puller.succeed("test -e /srv/backups/atlas-postgresql/all-$(date -u -d '3 days ago' +%F).sql.zstd")
            puller.fail("test -e /srv/backups/atlas-postgresql/all-$(date -u -d '4 days ago' +%F).sql.zstd")
            puller.succeed("test -e /srv/backups/atlas-postgresql/all-before-upgrade.sql.zstd")

        with subtest("the copy lands on the late-mounted disk"):
            puller.succeed("findmnt -n -o FSTYPE /srv/backups | grep -qx tmpfs")
            # Created by the unit after the mount, private to root.
            assert puller.succeed("stat -c %a /srv/backups/atlas-postgresql").strip() == "700"
            assert puller.succeed("stat -c %a /srv/backups/atlas-postgresql/all-$(date -u +%F).sql.zstd").strip() == "600"

        with subtest("a rebuilt host restores Nook's copy as root and only then starts PostgreSQL"):
            # The source serves a real cluster dump; the puller copies it, and
            # the rebuilt host restores that copy through the shared directory.
            source.succeed("install -o postgres -m 0600 ${dump} /var/backup/postgresql/all.sql.zstd")
            puller.succeed("systemctl start postgresql-backup-pull.service")
            puller.succeed("cp /srv/backups/atlas-postgresql/all-$(date -u +%F).sql.zstd /tmp/shared/copy.sql.zstd")
            rebuilt.wait_for_unit("multi-user.target")
            rebuilt.fail("systemctl is-active postgresql.service")
            rebuilt.succeed("forge-postgresql-restore /tmp/shared/copy.sql.zstd")
            rebuilt.succeed("test -f /var/lib/postgresql/18/.forge-upgrade-complete")
            rebuilt.succeed("test $(stat -c %U /var/lib/postgresql/18) = postgres")
            # The unit failed while the marker was missing; clear that first.
            status, journal = rebuilt.execute("systemctl reset-failed postgresql.service && systemctl start postgresql.service || { journalctl -u postgresql.service -n 40 --no-pager; exit 1; }")
            assert status == 0, journal
            assert rebuilt.succeed("sudo -u postgres psql -At -d application -c 'SELECT value FROM kept'").strip() == "restored"
      '';
    });
}
