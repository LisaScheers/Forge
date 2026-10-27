{
  nixos.atlas = {config, ...}: {
    matrix.plural = {
      enable = true;
      allowedRooms = [
        "!JhfHvvWnFwYhEKzlot:bylisa.dev"
        "!NQIGQqdtQEZKmXOooD:bylisa.dev"
        "!fEiZNnpdJmNLhtRcNw:bylisa.dev"
        "!DtGujQmwAFWjOZNonz:bylisa.dev"
        "!YjBtrJaLHdZbOycxkC:bylisa.dev"
        "!TFToFwMQyifpNLCcGa:bylisa.dev"
        "!DqeZkbYhmtDfsMUHfY:bylisa.dev"
        "!spztIYjpjIHDxpEWJs:bylisa.dev"
        "!SlbIfVoFLHvcAhNJAl:bylisa.dev"
        "!FAQhXHzcurAdMaNINe:bylisa.dev"
        "!StJHuKFstNgJVqTCrF:bylisa.dev"
        "!lGstaALKKazrjrbfeq:bylisa.dev"
        "!HFhiefsmHgROSzxcVp:bylisa.dev"
        "!arWzVrlMDwjRgeZOEo:bylisa.dev"
        "!iETtijEpVNadVEewzq:bylisa.dev"
        "!XcjXcHtDBtNMMUWZjP:bylisa.dev"
        "!deGNODYsnWeYosmfrf:bylisa.dev"
        "!bInBpaIsNtwSEClRaV:bylisa.dev"
        "!mQwAfTpbOZJZJpLsXD:bylisa.dev"
        "!GUlrjTBzBMcdoZZXsj:bylisa.dev"
        "!jLntrehfaMwpdnuYFy:bylisa.dev"
        "!hCdJteiOatlXJHTbAm:bylisa.dev"
        "!rDfdijNyPqPUerIDEZ:bylisa.dev"
        "!QUBhmHiTLrculNTctW:bylisa.dev"
        "!zhdLXaCUpCaPkvzQyo:bylisa.dev"
        "!jxUqPwtGbUqImaHrgT:bylisa.dev"
        "!dUoaSoWbhiBhiMQEyq:bylisa.dev"
        "!wWxtpqIlaxVBLRYhyZ:bylisa.dev"
        "!YeWRZvwFPmiZRJcZvX:bylisa.dev"
        "!BSjqWjEWiEYskgFfGd:bylisa.dev"
        "!TVanAIHULKScLLKCIM:bylisa.dev"
        # Unlisted rooms; verify root and thread archives before portal binding.
        "!iSjajRVZWpQeArlClN:bylisa.dev"
        "!runkZigMpyOgcDsoSn:bylisa.dev"
        "!IqRGXDmJMaerkCzOoW:bylisa.dev"
        "!keELZUdeXULkJhIUZc:bylisa.dev"
        "!JzxphdRnEZhiuaQDcH:bylisa.dev"
        "!lHzjkVsAxsDWirNHZj:bylisa.dev"
        "!NddKOuqwOBPMXMmGEo:bylisa.dev"
        "!sqaCZfCMYEKUlLYfhS:bylisa.dev"
        "!dZvvrbmIDxcFXlGZht:bylisa.dev"
        "!qbbOLcLoNaRiUuALSA:bylisa.dev"
        "!gOTvKPwoGAFBqryDsY:bylisa.dev"
        "!ipRTfSaZJAOaajtTSx:bylisa.dev"
        "!YdvtqRrwKzpykouqBg:bylisa.dev"
        "!FdFDDXwmRByHnLpmiB:bylisa.dev"
        "!vLrywIZyQuwUbQsRvk:bylisa.dev"
        "!iQeOSRpGiiJFlyqkhF:bylisa.dev"
        "!iuKwIdFyvmDwmpvWxf:bylisa.dev"
        "!RdzeyeQWFrWGSdSpuE:bylisa.dev"
        "!yCAXEsHXLmXcZtWIGC:bylisa.dev"
        "!qRpddWHRUyTsbzZKob:bylisa.dev"
        "!OpqWynkLJaNArtEwtM:bylisa.dev"
        "!kCocJOcUPVIUfBrkxw:bylisa.dev"
        "!YyaQfetQjoAmwYCPBb:bylisa.dev"
        "!JUMBjFJvvLmjnhXzLl:bylisa.dev"
        "!CLeFdjwlydZlmtneLb:bylisa.dev"
        "!RVFIfsFHYeooFZziiU:bylisa.dev"
        "!tXaaYcXCtmcbQjXcxw:bylisa.dev"
        "!HzyiKGZDslZUoquhWG:bylisa.dev"
        "!MPWPRWInwHuAnWKoNX:bylisa.dev"
      ];
      publicHost = "plural.bylisa.dev";
      secretsFile = config.age.secrets.pluralmatrix-credentials.path;
    };
    age.secrets.pluralmatrix-credentials = {
      file = ../../security/agenix/secrets/atlas/pluralmatrix-credentials.age;
      mode = "0400";
    };
    systemd.services.pluralmatrix-registration.restartTriggers = [config.age.secrets.pluralmatrix-credentials.file];
  };
  nixos.matrix = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.matrix.plural;
    registrationDirectory = "/var/lib/pluralmatrix-registration";
    registration = "${registrationDirectory}/registration.yaml";
    prepare = pkgs.writeShellApplication {
      name = "pluralmatrix-prepare";
      runtimeInputs = [pkgs.python3];
      text = ''
        python3 ${./plural-prepare.py} ${lib.escapeShellArg cfg.secretsFile} ${registrationDirectory} ${lib.escapeShellArg config.networking.domain}
      '';
    };
  in {
    options.matrix.plural = {
      enable = lib.mkEnableOption "PluralMatrix for reviewed Matrix rooms";
      allowedRooms = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
      };
      secretsFile = lib.mkOption {
        type = lib.types.str;
        default = "/run/agenix/pluralmatrix-credentials";
      };
      publicHost = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      loginHomeservers = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
      };
    };
    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = cfg.allowedRooms != [];
          message = "PluralMatrix requires an explicit reviewed room list";
        }
      ];
      users.groups.pluralmatrix = {};
      users.groups.matrix-secrets = {};
      users.users.pluralmatrix = {
        isSystemUser = true;
        group = "pluralmatrix";
      };
      users.users.matrix-synapse.extraGroups = ["pluralmatrix"];
      services.postgresql = {
        ensureDatabases = ["pluralmatrix"];
        ensureUsers = [
          {
            name = "pluralmatrix";
            ensureDBOwnership = true;
          }
        ];
      };
      services.matrix-synapse.settings = {
        app_service_config_files = [registration];
        experimental_features = {
          msc3202_device_masquerading = true;
          msc3202_transaction_extensions = true;
          msc2409_to_device_messages_enabled = true;
        };
      };
      systemd.services.matrix-synapse = {
        requires = ["pluralmatrix-registration.service"];
        after = ["pluralmatrix-registration.service"];
      };
      systemd.services.pluralmatrix-registration = {
        description = "Prepare protected PluralMatrix registration and credentials";
        before = ["matrix-synapse.service" "pluralmatrix.service"];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          StateDirectory = "pluralmatrix-registration";
          StateDirectoryMode = "0750";
          Group = "pluralmatrix";
          UMask = "0077";
          ExecStart = lib.getExe prepare;
        };
      };
      systemd.services.pluralmatrix = {
        description = "PluralMatrix member proxying";
        wantedBy = ["multi-user.target"];
        requires = ["postgresql.service" "matrix-synapse.service" "pluralmatrix-registration.service"];
        after = ["postgresql.service" "matrix-synapse.service" "pluralmatrix-registration.service"];
        environment = {
          DATABASE_URL = "postgresql://pluralmatrix@localhost/pluralmatrix?host=/run/postgresql";
          SYNAPSE_URL = "http://[::1]:8008";
          SYNAPSE_DOMAIN = config.networking.domain;
          APP_PORT = "29335";
          AS_PORT = "29336";
          GATEKEEPER_PORT = "29337";
          PLURAL_ALLOWED_ROOMS = lib.concatStringsSep "," cfg.allowedRooms;
          PLURAL_LOGIN_HOMESERVERS = builtins.toJSON cfg.loginHomeservers;
          PUBLIC_WEB_URL =
            if cfg.publicHost == null
            then "http://127.0.0.1:29335"
            else "https://${cfg.publicHost}";
          REGISTRATION_PATH = registration;
        };
        serviceConfig = {
          Type = "simple";
          User = "pluralmatrix";
          Group = "pluralmatrix";
          WorkingDirectory = "/var/lib/pluralmatrix";
          StateDirectory = "pluralmatrix";
          StateDirectoryMode = "0700";
          EnvironmentFile = "${registrationDirectory}/environment";
          ExecStartPre = "${pkgs.pluralmatrix}/bin/pluralmatrix-migrate";
          ExecStart = lib.getExe pkgs.pluralmatrix;
          Restart = "on-failure";
          RestartSec = 5;
          UMask = "0077";
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          NoNewPrivileges = true;
          PrivateDevices = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectControlGroups = true;
          RestrictSUIDSGID = true;
          RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6"];
          TimeoutStartSec = "2min";
          MemoryMax = "2G";
        };
      };
      systemd.services.mautrix-discord = lib.mkIf config.matrix.discord.enable {
        environment = {
          PLURALMATRIX_ROOMS = lib.concatStringsSep "," cfg.allowedRooms;
          PLURALMATRIX_DECISION_URL = "http://127.0.0.1:29337/decision";
        };
        serviceConfig.EnvironmentFile = lib.mkForce [config.services.mautrix-discord.environmentFile "${registrationDirectory}/bridge-environment"];
        requires = ["pluralmatrix-registration.service"];
        after = ["pluralmatrix-registration.service"];
      };
      systemd.services.mautrix-discord-registration = lib.mkIf config.matrix.discord.enable {
        serviceConfig.EnvironmentFile = lib.mkForce [config.services.mautrix-discord.environmentFile "${registrationDirectory}/bridge-environment"];
        requires = ["pluralmatrix-registration.service"];
        after = ["pluralmatrix-registration.service"];
      };
      services.mautrix-discord.settings.bridge = lib.mkIf (config.matrix.discord.enable && cfg.publicHost != null) {
        public_address = "https://${cfg.publicHost}";
        avatar_proxy_key = "$PLURALMATRIX_AVATAR_PROXY_KEY";
      };
      services.nginx.virtualHosts = lib.mkIf (cfg.publicHost != null) {
        ${cfg.publicHost} = {
          enableACME = true;
          forceSSL = true;
          locations."/" = {
            proxyPass = "http://127.0.0.1:29335";
            extraConfig = ''
              client_max_body_size 10m;
              add_header Referrer-Policy "no-referrer" always;
            '';
          };
          locations."/api/" = {
            proxyPass = "http://127.0.0.1:29335";
            extraConfig = ''
              client_max_body_size 10m;
              access_log off;
              add_header Referrer-Policy "no-referrer" always;
            '';
          };
          locations."/mautrix-discord/avatar/" = lib.mkIf config.matrix.discord.enable {
            proxyPass = "http://127.0.0.1:29334";
            extraConfig = ''
              access_log off;
              limit_except GET { deny all; }
              add_header Referrer-Policy "no-referrer" always;
            '';
          };
          locations."= /api/auth/login".extraConfig = ''
            limit_req zone=plural_login burst=5 nodelay;
            proxy_pass http://127.0.0.1:29335;
          '';
        };
      };
      services.nginx.appendHttpConfig = lib.mkIf (cfg.publicHost != null) ''
        limit_req_zone $binary_remote_addr zone=plural_login:1m rate=5r/m;
      '';
    };
  };
}
