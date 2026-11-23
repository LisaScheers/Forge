# Cognee's state, copied off Nook every night. Nook writes an archive encrypted
# to Lisa's age key; Atlas fetches it with a key that can read nothing else, so
# the off-site copy is ciphertext Atlas cannot open.
{
  config,
  lib,
  ...
}: let
  features = config.nixos;
  inherit (config.network) nook;
  pubkeys = config.secrets.pubkeys;
  # Values below go into a forced SSH command and scripts unescaped, so only
  # plain absolute paths and names are accepted.
  safePath = lib.types.strMatching "/[A-Za-z0-9._/-]+";
  safeName = lib.types.strMatching "[A-Za-z0-9._-]+";
  archiveName = "cognee.tar.zst.age";
in {
  nixos.cognee-backup = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.cogneeBackup;
    archive = "${cfg.destination}/${archiveName}";
    backup = pkgs.writeShellApplication {
      name = "cognee-backup";
      runtimeInputs = [pkgs.age pkgs.coreutils pkgs.gnutar pkgs.zstd];
      text = ''
        partial=${archive}.part
        trap 'rm -f "$partial"' EXIT
        tar -C ${cfg.storageRoot} -cf - ${lib.escapeShellArgs cfg.paths} | zstd -q -T0 | age -r ${cfg.recipient} > "$partial"
        chgrp cognee-backup "$partial"
        chmod 0640 "$partial"
        mv "$partial" ${archive}
      '';
    };
    # Serve only today's archive (UTC): an older one means tonight's backup
    # failed, and the copy must fail too instead of storing stale data as new.
    serve = pkgs.writeShellApplication {
      name = "serve-cognee-backup";
      runtimeInputs = [pkgs.coreutils];
      text = ''
        if [[ ! -f ${archive} ]]; then
          echo "${archive} is missing" >&2
          exit 1
        fi
        if [[ "$(date -u -r ${archive} +%F)" != "$(date -u +%F)" ]]; then
          echo "${archive} is from $(date -u -r ${archive} +%F), not today (UTC)" >&2
          exit 1
        fi
        exec cat ${archive}
      '';
    };
    systemctl = "${pkgs.systemd}/bin/systemctl";
  in {
    options.services.cogneeBackup = {
      storageRoot = lib.mkOption {
        type = safePath;
        description = "Directory holding Cognee's state.";
      };
      paths = lib.mkOption {
        type = lib.types.listOf safeName;
        description = "Directories under storageRoot to archive.";
      };
      stopUnits = lib.mkOption {
        type = lib.types.listOf safeName;
        description = "Units that write the state; they stop during the copy and start again afterwards.";
      };
      recipient = lib.mkOption {
        type = lib.types.strMatching "age1[a-z0-9]+";
        description = "age recipient that can decrypt the archive.";
      };
      destination = lib.mkOption {
        type = safePath;
        description = "Directory for the archive the reader serves.";
      };
      authorizedKey = lib.mkOption {
        type = lib.types.singleLineStr;
        description = "Public key that may fetch the archive; any command it asks for prints the archive instead.";
      };
      startAt = lib.mkOption {
        type = lib.types.singleLineStr;
        default = "*-*-* 03:15:00 UTC";
        description = "When to write the archive; give a time zone, as the hosts' clocks may differ.";
      };
    };

    config = {
      users.users.cognee-backup = {
        isSystemUser = true;
        group = "cognee-backup";
        useDefaultShell = true;
        home = cfg.destination;
        openssh.authorizedKeys.keys = [''restrict,command="${lib.getExe serve}" ${cfg.authorizedKey}''];
      };
      users.groups.cognee-backup = {};
      systemd.tmpfiles.rules = ["d ${cfg.destination} 0750 root cognee-backup - -"];

      systemd.services.cognee-backup = {
        description = "Write an encrypted Cognee backup";
        inherit (cfg) startAt;
        unitConfig.RequiresMountsFor = [cfg.storageRoot cfg.destination];
        serviceConfig = {
          Type = "oneshot";
          # A copy of a running graph and vector store may not open again.
          ExecStartPre = "${systemctl} stop ${lib.escapeShellArgs cfg.stopUnits}";
          ExecStart = lib.getExe backup;
          # Runs after failures too, so a broken copy never leaves Cognee down.
          ExecStopPost = "${systemctl} start --no-block ${lib.escapeShellArgs cfg.stopUnits}";
          TimeoutStartSec = "1h";
          UMask = "0077";
        };
      };
    };
  };

  nixos.cognee-backup-pull = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.cogneeBackupPull;
    knownHosts = pkgs.writeText "cognee-backup-pull-known-hosts" "${cfg.host} ${cfg.hostKey}\n";
    pull = pkgs.writeShellApplication {
      name = "cognee-backup-pull";
      runtimeInputs = [pkgs.coreutils pkgs.openssh];
      text = ''
        target="${cfg.destination}/cognee-$(date -u +%F).tar.zst.age"
        partial="$target.part"
        trap 'rm -f "$partial"' EXIT
        # A stalled link must end the run, or the timer would skip later copies.
        ssh -i "$CREDENTIALS_DIRECTORY/key" -o IdentitiesOnly=yes -o BatchMode=yes \
          -o ConnectTimeout=30 -o ServerAliveInterval=30 -o ServerAliveCountMax=4 \
          -o UserKnownHostsFile=${knownHosts} -o StrictHostKeyChecking=yes \
          "cognee-backup@${cfg.host}" > "$partial"
        # Atlas cannot decrypt the copy, so it checks that it is a whole age file.
        if [[ "$(head -c 21 "$partial")" != "age-encryption.org/v1" ]]; then
          echo "the copy is not an age file" >&2
          exit 1
        fi
        mv "$partial" "$target"
        # Prune by the UTC date in the name; ISO dates compare correctly as strings.
        oldest="cognee-$(date -u -d '${toString cfg.keepDays} days ago' +%F).tar.zst.age"
        shopt -s nullglob
        for copy in "${cfg.destination}"/cognee-[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].tar.zst.age; do
          if [[ "''${copy##*/}" < "$oldest" ]]; then
            rm -f -- "$copy"
          fi
        done
      '';
    };
  in {
    options.services.cogneeBackupPull = {
      host = lib.mkOption {
        type = safeName;
        description = "Address of the host that writes the archive.";
      };
      hostKey = lib.mkOption {
        type = lib.types.singleLineStr;
        description = "That host's SSH host key, pinned for the connection.";
      };
      keyFile = lib.mkOption {
        type = safePath;
        description = "Private key, loaded as a systemd credential.";
      };
      destination = lib.mkOption {
        type = safePath;
        default = "/var/backups/cognee";
        description = "Directory for the dated copies.";
      };
      keepDays = lib.mkOption {
        type = lib.types.ints.positive;
        default = 7;
        description = "Copies dated more than this many days before today (UTC) are deleted.";
      };
      startAt = lib.mkOption {
        type = lib.types.singleLineStr;
        default = "*-*-* 04:15:00 UTC";
        description = "When to copy, after the source's nightly archive.";
      };
    };

    config = {
      systemd.tmpfiles.rules = ["d ${cfg.destination} 0700 root root - -"];
      systemd.services.cognee-backup-pull = {
        description = "Copy the encrypted Cognee backup from ${cfg.host}";
        after = ["network-online.target"];
        wants = ["network-online.target"];
        inherit (cfg) startAt;
        serviceConfig = {
          Type = "oneshot";
          ExecStart = lib.getExe pull;
          TimeoutStartSec = "1h";
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

  nixos.nook = {
    imports = [features.cognee-backup];
    services.cogneeBackup = {
      storageRoot = "/srv/disks/projects/cognee";
      # The state docs/cognee.md lists; caches and images are re-created.
      paths = ["system" "data" "credentials" "openai" "mcp"];
      stopUnits = ["podman-cognee-mcp.service" "podman-cognee.service"];
      recipient = pubkeys.users.lisa;
      destination = "/srv/disks/projects/cognee-backup";
      authorizedKey = lib.removeSuffix "\n" (builtins.readFile ./atlas-backup-pull.pub);
    };
  };

  nixos.atlas = {config, ...}: {
    imports = [features.cognee-backup-pull];
    age.secrets.cognee-backup-pull-key.file = ../../security/agenix/secrets/atlas/cognee-backup-pull-key.age;
    services.cogneeBackupPull = {
      host = nook.tailscale;
      hostKey = pubkeys.hosts.nook;
      keyFile = config.age.secrets.cognee-backup-pull-key.path;
    };
  };
}
