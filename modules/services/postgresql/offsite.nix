{
  config,
  lib,
  ...
}: let
  features = config.nixos;
  # Values below go into a forced SSH command, a shell script and unit
  # settings unescaped, so only plain absolute paths and names are accepted.
  safePath = lib.types.strMatching "/[A-Za-z0-9._/-]+";
  safeName = lib.types.strMatching "[A-Za-z0-9._-]+";
  inherit (config.network) atlas;
  hostKeys = config.secrets.pubkeys.hosts;
in {
  # Atlas lets one key read its nightly dump and nothing else.
  nixos.postgresql-backup-reader = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.postgresqlBackupReader;
    # Serve only today's dump (UTC, as both timers run): a dump from another
    # day means tonight's backup failed or was missed, so the copy must fail
    # too instead of saving stale data as new.
    serve = pkgs.writeShellApplication {
      name = "serve-postgresql-dump";
      runtimeInputs = [pkgs.coreutils];
      text = ''
        dump=${cfg.dump}
        if [[ ! -f "$dump" ]]; then
          echo "$dump is missing" >&2
          exit 1
        fi
        if [[ "$(date -u -r "$dump" +%F)" != "$(date -u +%F)" ]]; then
          echo "$dump is from $(date -u -r "$dump" +%F), not today (UTC)" >&2
          exit 1
        fi
        exec cat "$dump"
      '';
    };
  in {
    options.services.postgresqlBackupReader = {
      authorizedKey = lib.mkOption {
        type = lib.types.singleLineStr;
        description = "Public key that may fetch the dump; any command it asks for prints the dump instead.";
      };
      dump = lib.mkOption {
        type = safePath;
        default = "${config.services.postgresqlBackup.location}/all.sql.zstd";
        defaultText = lib.literalExpression ''"''${config.services.postgresqlBackup.location}/all.sql.zstd"'';
        description = "Dump to serve.";
      };
    };
    config.users.users.postgres.openssh.authorizedKeys.keys = [
      ''restrict,command="${lib.getExe serve}" ${cfg.authorizedKey}''
    ];
  };

  # Nook copies that dump off Atlas daily, verifies it, and keeps two weeks.
  nixos.postgresql-backup-pull = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.postgresqlBackupPull;
    knownHosts = pkgs.writeText "postgresql-backup-pull-known-hosts" "${cfg.host} ${cfg.hostKey}\n";
    pull = pkgs.writeShellApplication {
      name = "postgresql-backup-pull";
      runtimeInputs = [pkgs.coreutils pkgs.openssh pkgs.zstd];
      text = ''
        target="${cfg.destination}/all-$(date -u +%F).sql.zstd"
        partial="$target.part"
        trap 'rm -f "$partial"' EXIT
        # A stalled link must end the run, or the timer would skip later copies.
        ssh -i "$CREDENTIALS_DIRECTORY/key" -o IdentitiesOnly=yes -o BatchMode=yes \
          -o ConnectTimeout=30 -o ServerAliveInterval=30 -o ServerAliveCountMax=4 \
          -o UserKnownHostsFile=${knownHosts} -o StrictHostKeyChecking=yes \
          "${cfg.user}@${cfg.host}" > "$partial"
        # A truncated or corrupt copy must not replace a good one.
        zstd --quiet --test "$partial"
        mv "$partial" "$target"
        # Prune by the UTC date in the name, so the limit doesn't drift with
        # the run's time of day; ISO dates compare correctly as strings.
        oldest="all-$(date -u -d '${toString cfg.keepDays} days ago' +%F).sql.zstd"
        shopt -s nullglob
        for copy in "${cfg.destination}"/all-[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].sql.zstd; do
          if [[ "''${copy##*/}" < "$oldest" ]]; then
            rm -f -- "$copy"
          fi
        done
      '';
    };
  in {
    options.services.postgresqlBackupPull = {
      host = lib.mkOption {
        type = safeName;
        description = "Address of the host whose dump is copied.";
      };
      hostKey = lib.mkOption {
        type = lib.types.singleLineStr;
        description = "That host's SSH host key, pinned for the connection.";
      };
      user = lib.mkOption {
        type = safeName;
        default = "postgres";
        description = "Account holding the restricted key on that host.";
      };
      keyFile = lib.mkOption {
        type = safePath;
        description = "Private key, loaded as a systemd credential.";
      };
      destination = lib.mkOption {
        type = safePath;
        description = "Directory for the dated copies.";
      };
      keepDays = lib.mkOption {
        type = lib.types.ints.positive;
        default = 14;
        description = "Copies dated more than this many days before today (UTC) are deleted.";
      };
      startAt = lib.mkOption {
        type = lib.types.singleLineStr;
        default = "*-*-* 04:30:00 UTC";
        description = "When to copy, after the source's nightly dump; give a time zone, as the hosts' clocks may differ.";
      };
    };

    config = {
      # The destination's disk mounts on demand, after boot-time tmpfiles ran,
      # and the pull's sandbox needs the directory before it starts (even a
      # "+" ExecStartPre runs inside its mount namespace), so a plain unit
      # creates it once the disk is mounted.
      systemd.services.postgresql-backup-pull-destination = {
        description = "Create the PostgreSQL copy directory ${cfg.destination}";
        unitConfig.RequiresMountsFor = cfg.destination;
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.coreutils}/bin/install -d -m 0700 ${cfg.destination}";
        };
      };
      systemd.services.postgresql-backup-pull = {
        description = "Copy the PostgreSQL dump from ${cfg.host}";
        after = ["network-online.target" "postgresql-backup-pull-destination.service"];
        wants = ["network-online.target"];
        requires = ["postgresql-backup-pull-destination.service"];
        inherit (cfg) startAt;
        unitConfig.RequiresMountsFor = cfg.destination;
        serviceConfig = {
          Type = "oneshot";
          ExecStart = lib.getExe pull;
          TimeoutStartSec = "1h";
          # Copies are root-only, like the dump on Atlas.
          UMask = "0077";
          LoadCredential = "key:${cfg.keyFile}";
          ProtectSystem = "strict";
          ReadWritePaths = [cfg.destination];
          ProtectHome = true;
          PrivateTmp = true;
          NoNewPrivileges = true;
          CapabilityBoundingSet = "";
          RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX"];
        };
      };
    };
  };

  nixos.atlas = {lib, ...}: {
    imports = [features.postgresql-backup-reader];
    services.postgresqlBackupReader.authorizedKey = lib.removeSuffix "\n" (builtins.readFile ./atlas-backup-pull.pub);
  };

  nixos.nook = {config, ...}: {
    imports = [features.postgresql-backup-pull];
    age.secrets.atlas-backup-pull-key.file = ../../security/agenix/secrets/nook/atlas-backup-pull-key.age;
    services.postgresqlBackupPull = {
      host = atlas.tailscale;
      hostKey = hostKeys.atlas;
      keyFile = config.age.secrets.atlas-backup-pull-key.path;
      destination = "/srv/disks/western-digital-hdd/backups/atlas-postgresql";
    };
  };
}
