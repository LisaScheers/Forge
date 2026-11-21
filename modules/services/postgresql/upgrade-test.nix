{lib, ...}: {
  perSystem = {pkgs, ...}: {
    checks = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
      postgresql-upgrade =
        pkgs.runCommand "postgresql-16-to-18" {
          nativeBuildInputs = [pkgs.postgresql_16 pkgs.postgresql_18 pkgs.zstd];
        } ''
          set -euo pipefail
          export HOME="$PWD"
          export PGHOST="$PWD/socket"
          export PGPORT=6543
          export PGUSER=postgres
          mkdir "$PGHOST"
          oldbin=${pkgs.postgresql_16}/bin
          newbin=${pkgs.postgresql_18}/bin
          cleanup() {
            for cluster in old new restored again empty nologin nosuper; do
              if test -f "$PWD/$cluster/postmaster.pid"; then
                "$newbin/pg_ctl" -D "$PWD/$cluster" -m immediate stop || true
              fi
            done
          }
          trap cleanup EXIT
          start_cluster() {
            "$1/pg_ctl" -D "$PWD/$2" -l "$PWD/$2.log" \
              -o "-c listen_addresses= -c unix_socket_directories=$PGHOST -p $PGPORT" -w start
          }

          "$oldbin/initdb" --no-locale --encoding=UTF8 -U postgres -D "$PWD/old"
          start_cluster "$oldbin" old
          "$oldbin/psql" -X -v ON_ERROR_STOP=1 -d postgres <<'SQL'
          CREATE ROLE application LOGIN;
          CREATE DATABASE application OWNER application;
          \connect application
          CREATE TABLE restored_data (value text PRIMARY KEY);
          INSERT INTO restored_data VALUES ('preserved');
          SQL
          "$oldbin/pg_dumpall" > "$PWD/backup.sql"
          "$oldbin/pg_ctl" -D "$PWD/old" -m fast -w stop

          # PostgreSQL 16's default cluster has checksums off; 18 defaults to on.
          "$newbin/initdb" --no-locale --encoding=UTF8 --no-data-checksums -U postgres -D "$PWD/new"
          upgrade_args=(-b "$oldbin" -B "$newbin" -d "$PWD/old" -D "$PWD/new" -U postgres --socketdir "$PGHOST")
          "$newbin/pg_upgrade" "''${upgrade_args[@]}" --check
          "$newbin/pg_upgrade" "''${upgrade_args[@]}"
          start_cluster "$newbin" new
          test "$("$newbin/psql" -X -At -d application -c 'SELECT value FROM restored_data')" = preserved
          "$newbin/psql" -X -v ON_ERROR_STOP=1 -d application -c "INSERT INTO restored_data VALUES ('new-cluster-only')"
          "$newbin/pg_ctl" -D "$PWD/new" -m fast -w stop

          # Copy mode leaves the original cluster independently recoverable.
          start_cluster "$oldbin" old
          test "$("$oldbin/psql" -X -At -d application -c 'SELECT count(*) FROM restored_data')" = 1
          "$oldbin/pg_ctl" -D "$PWD/old" -m fast -w stop

          # The restore Atlas's runbook uses (docs/atlas.md).
          restore=${lib.getExe (pkgs.callPackage ../../../packages/forge-postgresql-restore/package.nix {
            postgresql = pkgs.postgresql_18;
            dataDir = "/var/lib/postgresql/18";
            expectedDatabases = ["application"];
          })}
          zstd -q "$PWD/backup.sql" -o "$PWD/backup.sql.zstd"
          "$restore" "$PWD/backup.sql.zstd" "$PWD/restored"
          test -f "$PWD/restored/.forge-upgrade-complete"
          start_cluster "$newbin" restored
          test "$("$newbin/psql" -X -At -d application -c 'SELECT value FROM restored_data')" = preserved
          test "$("$newbin/psql" -X -At -d postgres -c "SELECT datdba::regrole FROM pg_database WHERE datname='application'")" = application
          # A later dump of the restored cluster contains its bootstrap role, and
          # restoring that dump must still work.
          "$newbin/pg_dumpall" | zstd -q -o "$PWD/again.sql.zstd"
          "$newbin/pg_ctl" -D "$PWD/restored" -m fast -w stop
          "$restore" "$PWD/again.sql.zstd" "$PWD/again"
          test -f "$PWD/again/.forge-upgrade-complete"

          # A corrupt or empty dump, or an existing cluster, never gets the marker.
          printf 'not zstd' > "$PWD/corrupt.sql.zstd"
          if "$restore" "$PWD/corrupt.sql.zstd" "$PWD/failed"; then exit 1; fi
          test ! -e "$PWD/failed/.forge-upgrade-complete"
          printf "" | zstd -q -o "$PWD/empty.sql.zstd"
          if "$restore" "$PWD/empty.sql.zstd" "$PWD/empty"; then exit 1; fi
          test ! -e "$PWD/empty/.forge-upgrade-complete"
          # The expected database is back, but postgres cannot log in or is no
          # superuser: still no marker.
          for broken in nologin:NOLOGIN nosuper:NOSUPERUSER; do
            name=''${broken%%:*}
            { zstd -dc "$PWD/backup.sql.zstd"; echo "ALTER ROLE postgres ''${broken#*:};"; } | zstd -q -o "$PWD/$name.sql.zstd"
            if "$restore" "$PWD/$name.sql.zstd" "$PWD/$name"; then exit 1; fi
            test ! -e "$PWD/$name/.forge-upgrade-complete"
          done
          if "$restore" "$PWD/backup.sql.zstd" "$PWD/again"; then exit 1; fi
          touch "$out"
        '';
    };
  };
}
