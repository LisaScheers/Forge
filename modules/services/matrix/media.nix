{config, ...}: let
  features = config.nixos;
in {
  nixos.atlas = {config, ...}: {
    imports = [features.matrix-media-client features.matrix-volume];
    matrix.volume = {
      enable = true;
      device = "/dev/disk/by-id/scsi-0HC_Volume_107199635";
    };
    services.nginx.virtualHosts."${config.matrix.subDomain}.${config.matrix.rootDomain}".locations."/_matrix".extraConfig = ''
      client_max_body_size 512m;
    '';
  };

  nixos.matrix-media-server = {
    config,
    lib,
    pkgs,
    utils,
    ...
  }: let
    cfg = config.matrix.mediaServer;
    uid = config.ids.uids.matrix-synapse;
    gid = config.ids.gids.matrix-synapse;
    diskUnit = "${utils.escapeSystemdPath cfg.diskMount}.mount";
    receiver = pkgs.writeShellScript "matrix-media-rsync" ''
      set -euo pipefail
      ${pkgs.util-linux}/bin/mountpoint -q ${lib.escapeShellArg cfg.diskMount}
      export PATH=${lib.makeBinPath [pkgs.rsync pkgs.coreutils]}
      exec ${pkgs.rrsync}/bin/rrsync -no-del ${lib.escapeShellArg cfg.directory}
    '';
  in {
    options.matrix.mediaServer = {
      enable = lib.mkEnableOption "the private Matrix media export";
      diskMount = lib.mkOption {
        type = lib.types.str;
        default = "/srv/disks/western-digital-hdd";
      };
      directory = lib.mkOption {
        type = lib.types.str;
        default = "${cfg.diskMount}/matrix-media";
      };
      address = lib.mkOption {
        type = lib.types.str;
        default = "100.106.233.104";
      };
      clientAddress = lib.mkOption {
        type = lib.types.str;
        default = "100.87.26.75";
      };
      interface = lib.mkOption {
        type = lib.types.str;
        default = "tailscale0";
      };
      networkUnit = lib.mkOption {
        type = lib.types.str;
        default = "tailscaled.service";
      };
      migrationPublicKeys = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Atlas keys restricted to media transfer and backup reads";
      };
    };

    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = lib.hasPrefix "${cfg.diskMount}/" cfg.directory;
          message = "Matrix media must live below its required disk mount";
        }
      ];
      users.groups.matrix-media.gid = gid;
      users.users.matrix-media = {
        isSystemUser = true;
        inherit uid;
        group = "matrix-media";
        shell = pkgs.bash;
        openssh.authorizedKeys.keys =
          map (
            key: ''from="${cfg.clientAddress}",restrict,command="${receiver}" ${key}''
          )
          cfg.migrationPublicKeys;
      };
      systemd.services.matrix-media-directory = {
        description = "Prepare Matrix media on the mounted HDD";
        unitConfig.RequiresMountsFor = cfg.diskMount;
        bindsTo = [diskUnit];
        after = [diskUnit];
        path = [pkgs.coreutils pkgs.gnugrep pkgs.util-linux];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          mountpoint -q ${lib.escapeShellArg cfg.diskMount}
          install -d -m 0700 -o matrix-media -g matrix-media ${lib.escapeShellArg cfg.directory}
          marker=${lib.escapeShellArg "${cfg.directory}/.matrix-media-store"}
          if test -e "$marker"; then
            grep -qx atlas-matrix-media-v1 "$marker"
          else
            printf '%s\n' atlas-matrix-media-v1 > "$marker"
            chmod 0444 "$marker"
          fi
        '';
      };
      services.nfs.server = {
        enable = true;
        hostName = cfg.address;
        # Reserved client ports and the tailnet peer are both required. All
        # requests use the dedicated media UID, never Nook's root identity.
        exports.${cfg.directory}.${cfg.clientAddress} = [
          "rw"
          "sync"
          "secure"
          "all_squash"
          "anonuid=${toString uid}"
          "anongid=${toString gid}"
          "no_subtree_check"
          "fsid=0"
        ];
      };
      services.nfs.settings.nfsd = {
        vers2 = false;
        vers3 = false;
        vers4 = true;
        udp = false;
        tcp = true;
      };
      networking.firewall.interfaces.${cfg.interface}.allowedTCPPorts = [2049];
      systemd.services.nfs-server = {
        requires = ["matrix-media-directory.service"];
        after = ["matrix-media-directory.service" cfg.networkUnit];
        bindsTo = ["matrix-media-directory.service"];
        serviceConfig = {
          Restart = "on-failure";
          RestartSec = 5;
        };
      };
      systemd.services.nfs-mountd = {
        requires = ["matrix-media-directory.service"];
        after = ["matrix-media-directory.service"];
      };
    };
  };

  nixos.matrix-media-client = {
    config,
    lib,
    pkgs,
    utils,
    ...
  }: let
    cfg = config.matrix.remoteMedia;
    automount = "${utils.escapeSystemdPath cfg.mountPoint}.automount";
    guard = pkgs.writeShellScript "require-matrix-media" ''
      set -euo pipefail
      # Reading the marker triggers the automount; failed mounts cannot expose
      # the underlying directory as a writable substitute for the NAS.
      test "$(${pkgs.coreutils}/bin/cat ${lib.escapeShellArg "${cfg.mountPoint}/.matrix-media-store"})" = atlas-matrix-media-v1
      ${pkgs.util-linux}/bin/findmnt -rn -M ${lib.escapeShellArg cfg.mountPoint} -t nfs4 > /dev/null
    '';
  in {
    options.matrix.remoteMedia = {
      enable = lib.mkEnableOption "Matrix media storage on Nook";
      serverAddress = lib.mkOption {
        type = lib.types.str;
        default = "100.106.233.104";
      };
      mountPoint = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/matrix-synapse/media_store";
      };
      networkUnit = lib.mkOption {
        type = lib.types.str;
        default = "tailscaled.service";
      };
      mountTimeout = lib.mkOption {
        type = lib.types.ints.positive;
        default = 60;
      };
    };

    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = config.services.matrix-synapse.enable;
          message = "Remote Matrix media requires Synapse";
        }
        {
          assertion = cfg.mountPoint == "${config.services.matrix-synapse.dataDir}/media_store";
          message = "Remote media must preserve the coordinated backup and restore layout";
        }
      ];
      boot.supportedFilesystems = ["nfs"];
      systemd.automounts = [
        {
          where = cfg.mountPoint;
          wantedBy = ["multi-user.target"];
          automountConfig.TimeoutIdleSec = "0";
        }
      ];
      systemd.mounts = [
        {
          what = "${cfg.serverAddress}:/";
          where = cfg.mountPoint;
          type = "nfs4";
          options = "vers=4.2,hard,resvport,nosuid,nodev,noexec,_netdev";
          after = ["network-online.target" cfg.networkUnit];
          wants = ["network-online.target"];
          requires = [cfg.networkUnit];
          mountConfig.TimeoutSec = cfg.mountTimeout;
        }
      ];
      services.matrix-synapse.settings = {
        media_store_path = cfg.mountPoint;
        max_upload_size = "512M";
      };
      systemd.services.matrix-synapse = {
        requires = [automount];
        after = [automount];
        bindsTo = [automount];
        serviceConfig.ExecStartPre = [guard];
      };
      systemd.services.restic-backups-matrix = lib.mkIf (config.services.restic.backups ? matrix) {
        requires = [automount];
        after = [automount];
        serviceConfig.ExecStartPre = [guard];
      };
    };
  };
}
