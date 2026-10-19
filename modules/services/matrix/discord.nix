{
  nixos.atlas = {
    config,
    lib,
    ...
  }: {
    matrix.discord = {
      enable = true;
      # General: 78,978 audited messages plus 51 newer arrivals fit this bound.
      # Each portal still requires its own access and history review.
      initialBackfillLimit = 90000;
    };
    age.secrets.discord-bridge-env = lib.mkIf config.matrix.discord.enable {
      file = ../../security/agenix/secrets/atlas/discord-bridge-env.age;
      owner = "root";
      mode = "0400";
    };
    matrix.discord.environmentFile = lib.mkIf config.matrix.discord.enable (
      lib.mkDefault config.age.secrets.discord-bridge-env.path
    );
  };

  nixos.matrix = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.matrix.discord;
    domain = config.networking.domain;
  in {
    options.matrix.discord = {
      enable = lib.mkEnableOption "the SEC-Hive Discord bridge";
      environmentFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Runtime environment file containing DISCORD_PROVISIONING_SECRET; never a Nix-store secret";
      };
      initialBackfillLimit = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 0;
        description = "Measured upper bound on messages per channel, set before enabling the bridge";
      };
      federateRooms = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Allow federation in newly created rooms; use false only for disposable local pilot rooms";
      };
      readOnlyChannels = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Discord channel IDs mirrored into Matrix without outbound writes";
      };
    };

    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = cfg.environmentFile != null;
          message = "matrix.discord.environmentFile must provide a runtime provisioning secret";
        }
        {
          assertion = cfg.initialBackfillLimit > 0;
          message = "Inventory SEC-Hive and set matrix.discord.initialBackfillLimit before creating portals";
        }
      ];

      services.mautrix-discord = {
        enable = true;
        # Unencrypted rooms do not need the deprecated libolm dependency.
        package = pkgs.mautrix-discord.overrideAttrs {
          tags = ["nocrypto"];
          buildInputs = [];
          patches = [
            ./discord-relay-recovery.patch
            ./discord-relay-features.patch
            ./discord-plural.patch
            ./discord-history.patch
            ./discord-reaction-history.patch
            ./discord-history-content.patch
            ./discord-missing-thread-starter.patch
          ];
          doCheck = true;
        };
        registerToSynapse = true;
        inherit (cfg) environmentFile;
        settings = {
          homeserver = {
            address = "http://[::1]:8008";
            inherit domain;
          };
          appservice = {
            address = "http://127.0.0.1:29334";
            hostname = "127.0.0.1";
            port = 29334;
            database = {
              type = "postgres";
              uri = "postgresql:///mautrix-discord?host=/run/postgresql";
            };
          };
          bridge = {
            permissions = {
              "*" = "relay";
              "@lisa:${domain}" = "admin";
              "@sec-hive-relay:${domain}" = "admin";
            };
            # No guilds are linked by enabling the service. Each portal needs an
            # explicit access/history review before it is created.
            restricted_rooms = false;
            federate_rooms = cfg.federateRooms;
            startup_private_channel_create_limit = 0;
            delete_portal_on_channel_delete = false;
            delete_guild_on_leave = false;
            direct_media.enabled = false;
            message_error_notices = true;
            encryption = {
              allow = false;
              default = false;
              require = false;
              allow_key_sharing = false;
            };
            backfill = {
              forward_limits = {
                initial = {
                  dm = 0;
                  channel = cfg.initialBackfillLimit;
                  thread = cfg.initialBackfillLimit;
                };
                missed = {
                  dm = 0;
                  channel = -1;
                  thread = -1;
                };
              };
              max_guild_members = -1;
            };
            provisioning = {
              shared_secret = "$DISCORD_PROVISIONING_SECRET";
              debug_endpoints = false;
            };
          };
        };
      };

      services.postgresql = {
        ensureDatabases = ["mautrix-discord"];
        ensureUsers = [
          {
            name = "mautrix-discord";
            ensureDBOwnership = true;
          }
        ];
      };
      systemd.services.mautrix-discord = {
        environment.SEC_HIVE_READ_ONLY_CHANNELS = lib.concatStringsSep "," cfg.readOnlyChannels;
        requires = ["postgresql.service"];
        after = ["postgresql.service"];
        serviceConfig.UMask = lib.mkForce "0077";
      };
      systemd.services.mautrix-discord-registration.serviceConfig.UMask = lib.mkForce "0077";
    };
  };
}
