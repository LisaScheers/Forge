# Restores a pg_dumpall dump into a new PostgreSQL 18 cluster and marks it
# ready for Forge only after every step succeeded. Atlas installs it, and
# modules/services/postgresql/tests.nix runs it.
{
  coreutils,
  lib,
  postgresql_18,
  util-linux,
  writeShellApplication,
  zstd,
  # Atlas passes its own server package, data directory and the databases its
  # dump must contain (modules/services/postgresql/restore.nix).
  postgresql ? postgresql_18,
  dataDir ? "/var/lib/postgresql/18",
  expectedDatabases ? [],
}:
writeShellApplication {
  name = "forge-postgresql-restore";
  runtimeInputs = [coreutils postgresql util-linux zstd];
  text = ''
    if [[ $# -lt 1 || $# -gt 2 ]]; then
      echo "usage: forge-postgresql-restore DUMP.sql.zstd [DATA_DIR]" >&2
      exit 2
    fi
    dump=$1
    data=''${2:-${dataDir}}

    # As root the cluster runs as postgres; tests run it as the calling user.
    as_postgres() {
      if [[ "$(id -u)" == 0 ]]; then
        runuser -u postgres -- "$@"
      else
        "$@"
      fi
    }

    # A wrong path or corrupt archive must fail before a cluster exists.
    zstd --quiet --test "$dump"
    if [[ -e "$data/PG_VERSION" ]]; then
      echo "$data already holds a cluster; refusing to restore over it" >&2
      exit 1
    fi
    # A fresh name, so a dump of a cluster restored this way never contains it.
    role="restore_$(date +%Y%m%d%H%M%S)_$$"
    # A private socket directory and no TCP: nothing else can reach the
    # cluster, which trusts local connections, while it is restored.
    socket=$(as_postgres mktemp -d)
    stop() {
      as_postgres pg_ctl -D "$data" -m fast -w stop
    }
    # On failure, show the server log before its directory is removed.
    cleanup() {
      local exit_status=$?
      if [[ "$exit_status" != 0 && -f "$socket/server.log" ]]; then
        tail -n 30 "$socket/server.log" >&2
      fi
      stop >/dev/null 2>&1 || true
      rm -rf "$socket"
    }
    trap cleanup EXIT

    if [[ "$(id -u)" == 0 ]]; then
      install -d -o postgres -g postgres -m 0700 "$data"
    fi
    as_postgres initdb --encoding=UTF8 -U "$role" -D "$data" >/dev/null
    as_postgres pg_ctl -D "$data" -w -l "$socket/server.log" \
      -o "-c listen_addresses= -c unix_socket_directories=$socket" start >/dev/null
    sql() {
      as_postgres psql -h "$socket" -X -q -v ON_ERROR_STOP=1 -U "$role" -d postgres "$@"
    }
    zstd -dc "$dump" | sql
    echo "Restored databases:"
    sql -At -c "SELECT datname FROM pg_database WHERE NOT datistemplate ORDER BY datname"
    # A valid archive can still hold no real dump; require what Atlas needs.
    expected=(${lib.escapeShellArgs expectedDatabases})
    for database in "''${expected[@]}"; do
      if [[ "$(sql -At -c "SELECT count(*) FROM pg_database WHERE datname = '$database'")" != 1 ]]; then
        echo "The dump did not restore database $database; no marker created" >&2
        exit 1
      fi
    done
    if [[ "$(sql -At -c "SELECT count(*) FROM pg_roles WHERE rolname = 'postgres'")" != 1 ]]; then
      echo "The dump did not restore the postgres role; no marker created" >&2
      exit 1
    fi
    # The bootstrap role still owns the catalogs; it just may not log in.
    sql -c "ALTER ROLE \"$role\" NOLOGIN"
    stop >/dev/null
    trap 'rm -rf "$socket"' EXIT
    as_postgres touch "$data/.forge-upgrade-complete"
    echo "Created $data/.forge-upgrade-complete; postgresql.service can start."
  '';
}
