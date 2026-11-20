{config, ...}: let
  features = config.nixos;
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
  in {
    options.services.postgresqlBackupReader = {
      authorizedKey = lib.mkOption {
        type = lib.types.str;
        description = "Public key that may fetch the dump; any command it asks for prints the dump instead.";
      };
      dump = lib.mkOption {
        type = lib.types.str;
        default = "${config.services.postgresqlBackup.location}/all.sql.zstd";
        defaultText = lib.literalExpression ''"''${config.services.postgresqlBackup.location}/all.sql.zstd"'';
        description = "Dump to serve.";
      };
    };
    config.users.users.postgres.openssh.authorizedKeys.keys = [
      ''restrict,command="${pkgs.coreutils}/bin/cat ${cfg.dump}" ${cfg.authorizedKey}''
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
      runtimeInputs = [pkgs.coreutils pkgs.findutils pkgs.openssh pkgs.zstd];
      text = ''
        target="${cfg.destination}/all-$(date +%F).sql.zstd"
        partial="$target.part"
        trap 'rm -f "$partial"' EXIT
        ssh -i "$CREDENTIALS_DIRECTORY/key" -o IdentitiesOnly=yes -o BatchMode=yes \
          -o UserKnownHostsFile=${knownHosts} -o StrictHostKeyChecking=yes \
          "${cfg.user}@${cfg.host}" > "$partial"
        # A truncated or corrupt copy must not replace a good one.
        zstd --quiet --test "$partial"
        mv "$partial" "$target"
        find "${cfg.destination}" -name 'all-*.sql.zstd' -mtime +${toString cfg.keepDays} -delete
      '';
    };
  in {
    options.services.postgresqlBackupPull = {
      host = lib.mkOption {
        type = lib.types.str;
        description = "Address of the host whose dump is copied.";
      };
      hostKey = lib.mkOption {
        type = lib.types.str;
        description = "That host's SSH host key, pinned for the connection.";
      };
      user = lib.mkOption {
        type = lib.types.str;
        default = "postgres";
        description = "Account holding the restricted key on that host.";
      };
      keyFile = lib.mkOption {
        type = lib.types.str;
        description = "Private key, loaded as a systemd credential.";
      };
      destination = lib.mkOption {
        type = lib.types.str;
        description = "Directory for the dated copies.";
      };
      keepDays = lib.mkOption {
        type = lib.types.ints.positive;
        default = 14;
        description = "Days a copy is kept.";
      };
      startAt = lib.mkOption {
        type = lib.types.str;
        default = "*-*-* 04:30:00";
        description = "When to copy; after the source's nightly dump.";
      };
    };

    config = {
      systemd.tmpfiles.rules = ["d ${cfg.destination} 0700 root root - -"];
      systemd.services.postgresql-backup-pull = {
        description = "Copy the PostgreSQL dump from ${cfg.host}";
        after = ["network-online.target"];
        wants = ["network-online.target"];
        inherit (cfg) startAt;
        unitConfig.RequiresMountsFor = cfg.destination;
        serviceConfig = {
          Type = "oneshot";
          ExecStart = lib.getExe pull;
          LoadCredential = "key:${cfg.keyFile}";
          ProtectSystem = "strict";
          ReadWritePaths = [cfg.destination];
          ProtectHome = true;
          PrivateTmp = true;
          NoNewPrivileges = true;
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
