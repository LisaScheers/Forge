{lib, ...}: {
  perSystem = {pkgs, ...}: {
    checks = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
      postgresql-upgrade =
        pkgs.runCommand "postgresql-16-to-18" {
          nativeBuildInputs = [pkgs.postgresql_16 pkgs.postgresql_18];
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
            for cluster in old new restored; do
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

          # Use a distinct bootstrap role so the dump can recreate its own roles.
          "$newbin/initdb" --no-locale --encoding=UTF8 -U restore_admin -D "$PWD/restored"
          start_cluster "$newbin" restored
          "$newbin/psql" -X -v ON_ERROR_STOP=1 -U restore_admin -d postgres -f "$PWD/backup.sql"
          test "$("$newbin/psql" -X -At -d application -c 'SELECT value FROM restored_data')" = preserved
          test "$("$newbin/psql" -X -At -d postgres -c "SELECT datdba::regrole FROM pg_database WHERE datname='application'")" = application
          "$newbin/pg_ctl" -D "$PWD/restored" -m fast -w stop
          touch "$out"
        '';
    };
  };
}
