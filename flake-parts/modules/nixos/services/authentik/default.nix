{inputs, ...}: {
  flake-file.inputs.authentik-nix = {
    # 2026.8.3 packaging; return to the default branch once upstream PR #193 is merged.
    url = "github:nix-community/authentik-nix/a22b8f03bff0e04e9cee3221114fae1d0f1bec50";
  };

  forge.modules.nixos.services_authentik = {
    config,
    lib,
    pkgs,
    ...
  }: let
    inherit (lib) mkDefault mkEnableOption mkIf mkMerge mkOption types;

    cfg = config.services.authentik;
    settingsFormat = pkgs.formats.yaml {};
    acmeCredentials = lib.optionals (cfg.nginx.enable && cfg.nginx.enableACME) [
      "${cfg.nginx.host}.pem:${config.security.acme.certs.${cfg.nginx.host}.directory}/fullchain.pem"
      "${cfg.nginx.host}.key:${config.security.acme.certs.${cfg.nginx.host}.directory}/key.pem"
    ];
  in {
    options.services.authentik = {
      enable = (mkEnableOption "authentik") // {default = true;};

      authentikComponents = mkOption {
        type = types.attrsOf types.package;
        # Keep upstream's tested Python and native dependency versions together.
        default = {
          inherit
            (inputs.authentik-nix.packages.${pkgs.stdenv.hostPlatform.system})
            rust
            pythonEnv
            staticWorkdirDeps
            migrate
            manage
            ;
        };
        description = "Native Authentik components from authentik-nix.";
      };

      settings = mkOption {
        type = types.submodule {
          freeformType = settingsFormat.type;
          options = {};
        };
        default = {};
      };

      createDatabase = mkOption {
        type = types.bool;
        default = true;
      };

      environmentFile = mkOption {
        type = types.nullOr types.path;
        default = null;
      };

      worker = {
        listenHTTP = mkOption {
          type = types.str;
          default = "127.0.0.1:9001";
        };

        listenMetrics = mkOption {
          type = types.str;
          default = "127.0.0.1:9301";
        };
      };

      nginx = {
        enable = mkEnableOption "basic nginx configuration";
        enableACME = mkEnableOption "Let's Encrypt and certificate discovery";
        host = mkOption {
          type = types.str;
          example = "auth.example.com";
        };
      };
    };

    config = mkIf cfg.enable {
      services.authentik.settings = {
        listen = {
          http = mkDefault ["127.0.0.1:9000"];
          https = mkDefault ["127.0.0.1:9443"];
          metrics = mkDefault ["127.0.0.1:9300"];
        };
        postgresql = mkIf cfg.createDatabase {
          user = mkDefault "authentik";
          name = mkDefault "authentik";
          host = mkDefault "";
        };
        cert_discovery_dir = mkIf (cfg.nginx.enable && cfg.nginx.enableACME) "env://CREDENTIALS_DIRECTORY";
        blueprints_dir = mkDefault "${cfg.authentikComponents.staticWorkdirDeps}/blueprints";
        storage.media = {
          backend = mkDefault "file";
          file.path = mkDefault "/var/lib/authentik/media";
        };
        media.enable_upload = mkDefault true;
      };

      environment.etc."authentik/config.yml".source =
        settingsFormat.generate "authentik.yml" cfg.settings;

      environment.systemPackages = [
        (pkgs.writeShellScriptBin "ak" ''
          exec ${cfg.authentikComponents.manage}/bin/manage.py "$@"
        '')
      ];

      services.redis.servers.authentik = {
        enable = true;
        port = 6379;
      };

      services.postgresql = mkIf cfg.createDatabase {
        enable = true;
        ensureDatabases = ["authentik"];
        ensureUsers = [
          {
            name = "authentik";
            ensureDBOwnership = true;
          }
        ];
      };

      systemd.services = let
        authentikRuntimeEnvironment = ''
          export PATH="${cfg.authentikComponents.pythonEnv}/bin:$PATH"
          export PYTHONPATH="${cfg.authentikComponents.staticWorkdirDeps}"
          export PYTHONDONTWRITEBYTECODE=1
          export PYTHONUNBUFFERED=1
          cd ${cfg.authentikComponents.staticWorkdirDeps}
        '';

        migrateScript = pkgs.writeShellScript "authentik-migrate" ''
          ${authentikRuntimeEnvironment}
          exec ${cfg.authentikComponents.migrate}/bin/migrate.py
        '';

        serverScript = pkgs.writeShellScript "authentik-server" ''
          ${authentikRuntimeEnvironment}
          exec ${cfg.authentikComponents.rust}/bin/authentik server
        '';

        workerScript = pkgs.writeShellScript "authentik-worker" ''
          ${authentikRuntimeEnvironment}

          # The supervisor owns worker registration, health checks and child processes.
          exec ${cfg.authentikComponents.rust}/bin/authentik worker
        '';

        serviceDefaults = {
          DynamicUser = true;
          User = "authentik";
          EnvironmentFile = mkIf (cfg.environmentFile != null) [cfg.environmentFile];
          Environment = [
            "AUTHENTIK_CONFIG=/etc/authentik/config.yml"
            "PROMETHEUS_MULTIPROC_DIR=%S/authentik/prometheus"
          ];
          ExecStartPre = [
            "${pkgs.coreutils}/bin/mkdir -p %S/authentik/prometheus"
          ];
        };
      in {
        authentik-migrate = {
          requires = lib.optionals cfg.createDatabase ["postgresql.service"];
          wants = ["network-online.target"];
          after = ["network-online.target"] ++ lib.optionals cfg.createDatabase ["postgresql.service"];
          before = ["authentik.service" "authentik-worker.service"];
          restartTriggers = [config.environment.etc."authentik/config.yml".source];
          serviceConfig = mkMerge [
            serviceDefaults
            {
              Type = "oneshot";
              RemainAfterExit = true;
              StateDirectory = "authentik";
              RuntimeDirectory = "authentik-migrate";
              Environment = ["TMPDIR=%t/authentik-migrate"];
              WorkingDirectory = "%S/authentik";
              ExecStart = migrateScript;
            }
          ];
        };

        authentik-worker = {
          wantedBy = ["multi-user.target"];
          wants = ["network-online.target"];
          requires = ["authentik-migrate.service"];
          after = ["network-online.target" "authentik-migrate.service"];
          restartTriggers = [config.environment.etc."authentik/config.yml".source];
          environment = {
            AUTHENTIK_LISTEN__HTTP = cfg.worker.listenHTTP;
            AUTHENTIK_LISTEN__METRICS = cfg.worker.listenMetrics;
          };
          serviceConfig = mkMerge [
            serviceDefaults
            {
              StateDirectory = "authentik";
              RuntimeDirectory = "authentik-worker";
              Environment = ["TMPDIR=%t/authentik-worker"];
              WorkingDirectory = "%S/authentik";
              ExecStart = workerScript;
              Restart = "on-failure";
              RestartSec = "1s";
              LoadCredential = acmeCredentials;
            }
          ];
        };

        authentik = {
          wantedBy = ["multi-user.target"];
          wants = ["network-online.target"];
          requires = ["authentik-migrate.service" "authentik-worker.service"];
          after =
            ["network-online.target" "redis-authentik.service" "authentik-migrate.service"]
            ++ lib.optionals cfg.createDatabase ["postgresql.service"];
          restartTriggers = [config.environment.etc."authentik/config.yml".source];
          serviceConfig = mkMerge [
            serviceDefaults
            {
              StateDirectory = "authentik";
              RuntimeDirectory = "authentik-server";
              Environment = ["TMPDIR=%t/authentik-server"];
              UMask = "0027";
              WorkingDirectory = "%S/authentik";
              ExecStart = serverScript;
              Restart = "on-failure";
              RestartSec = "1s";
              LoadCredential = acmeCredentials;
            }
          ];
        };
      };

      services.nginx = mkIf cfg.nginx.enable {
        enable = true;
        recommendedTlsSettings = true;
        recommendedProxySettings = true;
        virtualHosts.${cfg.nginx.host} = {
          inherit (cfg.nginx) enableACME;
          forceSSL = cfg.nginx.enableACME;
          locations."/" = {
            proxyWebsockets = true;
            proxyPass = "https://127.0.0.1:9443";
          };
        };
      };
    };
  };
}
