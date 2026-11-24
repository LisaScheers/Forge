# Cognee's state, archived on Nook every night and encrypted to Lisa's age key.
# The archive stays on Nook; no other host receives a copy.
{
  config,
  lib,
  ...
}: let
  features = config.nixos;
  pubkeys = config.secrets.pubkeys;
  # Values below go into scripts unescaped, so only plain absolute paths and
  # names are accepted.
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
        mv "$partial" ${archive}
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
        description = "Directory for the archive.";
      };
      startAt = lib.mkOption {
        type = lib.types.singleLineStr;
        default = "*-*-* 03:15:00 UTC";
        description = "When to write the archive.";
      };
    };

    config = {
      systemd.tmpfiles.rules = ["d ${cfg.destination} 0700 root root - -"];

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

  nixos.nook = {
    imports = [features.cognee-backup];
    services.cogneeBackup = {
      storageRoot = "/srv/disks/projects/cognee";
      # The state docs/cognee.md lists; caches and images are re-created.
      paths = ["system" "data" "credentials" "openai" "mcp"];
      stopUnits = ["podman-cognee-mcp.service" "podman-cognee.service"];
      recipient = pubkeys.users.lisa;
      destination = "/srv/disks/projects/cognee-backup";
    };
  };
}
