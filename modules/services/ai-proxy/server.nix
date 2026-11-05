{
  config,
  lib,
  ...
}: let
  domain = "cliproxy.local.bylisa.dev";
  source = ../../../services/ai-usage;
  secrets = ../../security/agenix/secrets;
in {
  overlays.ai-proxy = final: _prev: {
    cli-proxy-api-plus-capture = final.callPackage ../../../packages/cli-proxy-api-plus-capture.pkg.nix {};
  };
  flake.agenixRules = {
    "secrets/shared/ai-proxy-client-key.age".publicKeys = with config.secrets.pubkeys; [users.lisa hosts.nook hosts.vega hosts.atlas];
    "secrets/nook/ai-proxy-openrouter-key.age".publicKeys = with config.secrets.pubkeys; [users.lisa hosts.nook];
    "secrets/nook/ai-proxy-codex-auth.age".publicKeys = with config.secrets.pubkeys; [users.lisa hosts.nook];
    "secrets/nook/ai-proxy-antigravity-auth.age".publicKeys = with config.secrets.pubkeys; [users.lisa hosts.nook];
  };
  perSystem = {pkgs, ...}: {
    packages.cli-proxy-api-plus-capture = lib.mkIf pkgs.stdenv.hostPlatform.isLinux pkgs.cli-proxy-api-plus-capture;
    checks.ai-usage = pkgs.runCommand "ai-usage-tests" {} ''
      ${pkgs.python3}/bin/python3 -B -m unittest discover -s ${source} -v
      touch "$out"
    '';
    checks.ai-usage-clickhouse = lib.mkIf pkgs.stdenv.hostPlatform.isLinux (pkgs.runCommand "ai-usage-clickhouse-tests" {
        CLICKHOUSE_BINARY = "${pkgs.clickhouse}/bin/clickhouse";
        CLIPROXY_BINARY = "${pkgs.cli-proxy-api-plus-capture}/bin/cli-proxy-api-plus";
        AI_USAGE_CLICKHOUSE_PASSWORD = "test";
      } ''
        ${pkgs.python3.withPackages (ps: [ps.aiohttp])}/bin/python3 -B -m unittest discover -s ${source} -v
        touch "$out"
      '');
  };
  nixos.nook = {
    config,
    pkgs,
    ...
  }: let
    root = "/srv/disks/projects/ai-proxy";
    databaseRoot = "/srv/disks/projects/ai-usage";
    databaseEnv = "/srv/disks/projects/ai-usage-secrets/clickhouse.env";
    template = pkgs.writeText "cli-proxy-api-plus.json" (builtins.toJSON {
      host = "127.0.0.1";
      port = 8317;
      auth-dir = "${root}/auth";
      remote-management = {
        allow-remote = false;
        secret-key = "";
        disable-control-panel = true;
      };
      request-log = true;
      commercial-mode = false;
      usage-statistics-enabled = true;
      logging-to-file = false;
      logs-max-total-size-mb = 0;
      error-logs-max-files = 0;
      ws-auth = true;
      routing.session-affinity = true;
      # Antigravity CLI's Gemini mode strips the thinking suffix from its model ID.
      oauth-model-alias.antigravity = [
        {
          name = "gemini-3.8-flash-high";
          alias = "gemini-3.8-flash";
          fork = true;
        }
      ];
      openai-compatibility = [
        {
          name = "openrouter";
          prefix = "openrouter";
          base-url = "https://openrouter.ai/api/v1";
          models = [
            {
              name = "z-ai/glm-5.3-flash";
              alias = "glm-5.3-flash";
            }
          ];
        }
      ];
    });
    hardening = {
      UMask = "0077";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [root];
      RestrictSUIDSGID = true;
    };
  in {
    age.secrets = {
      ai-proxy-client-key = {
        file = secrets + /shared/ai-proxy-client-key.age;
        owner = "lisa";
        group = "ai-proxy-clients";
        mode = "0440";
      };
      ai-proxy-openrouter-key.file = secrets + /nook/ai-proxy-openrouter-key.age;
      ai-proxy-codex-auth.file = secrets + /nook/ai-proxy-codex-auth.age;
      ai-proxy-antigravity-auth.file = secrets + /nook/ai-proxy-antigravity-auth.age;
    };
    users.users.ai-proxy = {
      isSystemUser = true;
      group = "ai-proxy";
    };
    users.groups.ai-proxy = {};
    users.groups.ai-proxy-clients.members = ["lisa" "codex"];
    home-manager.users.codex = {
      home = {
        username = "codex";
        homeDirectory = "/home/codex";
        stateVersion = "26.11";
      };
      programs.codex = {
        enable = true;
        mutableSettings = true;
        settings = {
          model_provider = "nook";
          model_providers.nook = {
            name = "CLIProxy on Nook";
            base_url = "https://${domain}/v1";
            wire_api = "responses";
            supports_websockets = true;
            auth = {
              command = "${pkgs.coreutils}/bin/cat";
              args = [config.age.secrets.ai-proxy-client-key.path];
            };
          };
        };
      };
    };
    systemd.tmpfiles.rules = [
      "d ${root} 0700 ai-proxy ai-proxy - -"
      "d ${root}/logs 0700 ai-proxy ai-proxy - -"
      "d ${databaseRoot} 0700 clickhouse clickhouse - -"
      "d /srv/disks/projects/ai-usage-secrets 0700 root root - -"
    ];
    systemd.services.ai-usage-secrets = {
      before = ["clickhouse.service"];
      after = ["systemd-tmpfiles-setup.service"];
      unitConfig.RequiresMountsFor = ["/srv/disks/projects"];
      serviceConfig.Type = "oneshot";
      script = ''
        umask 077
        if [ ! -s ${databaseEnv} ]; then
          ${pkgs.python3}/bin/python3 -c 'import secrets; print("AI_USAGE_CLICKHOUSE_PASSWORD=" + secrets.token_hex(32))' > ${databaseEnv}
        fi
      '';
    };
    systemd.services.ai-proxy-cognee-env = {
      before = ["podman-cognee.service"];
      serviceConfig = {
        Type = "oneshot";
        RuntimeDirectory = "ai-proxy-cognee";
        RuntimeDirectoryMode = "0700";
        RemainAfterExit = true;
        UMask = "0077";
        LoadCredential = ["client-key:${config.age.secrets.ai-proxy-client-key.path}"];
      };
      restartTriggers = [config.age.secrets.ai-proxy-client-key.file];
      script = ''
        { printf 'LLM_API_KEY='; cat "$CREDENTIALS_DIRECTORY/client-key"; printf '\n'; } > /run/ai-proxy-cognee/client.env
      '';
    };
    services.clickhouse = {
      enable = true;
      serverConfig = {
        listen_host = "127.0.0.1";
        path = "${databaseRoot}/";
        tmp_path = "${databaseRoot}/tmp/";
        user_files_path = "${databaseRoot}/user_files/";
        format_schema_path = "${databaseRoot}/format_schemas/";
        max_server_memory_usage = 2147483648;
      };
      extraUsersConfig = ''
        <clickhouse><users><default>
          <password from_env="AI_USAGE_CLICKHOUSE_PASSWORD"/>
          <networks replace="replace"><ip>127.0.0.1</ip></networks>
        </default></users></clickhouse>
      '';
    };
    systemd.services.clickhouse = {
      requires = ["ai-usage-secrets.service"];
      after = ["ai-usage-secrets.service" "systemd-tmpfiles-setup.service"];
      unitConfig.RequiresMountsFor = ["/srv/disks/projects"];
      serviceConfig.EnvironmentFile = databaseEnv;
    };
    systemd.services.ai-usage-schema = {
      requires = ["clickhouse.service"];
      after = ["clickhouse.service"];
      serviceConfig =
        hardening
        // {
          Type = "oneshot";
          User = "ai-proxy";
          RemainAfterExit = true;
          EnvironmentFile = databaseEnv;
          ExecStart = "${pkgs.python3}/bin/python3 ${source}/ingest.py init";
        };
    };
    systemd.services.cli-proxy-api-plus = {
      description = "Shared AI gateway with complete request capture";
      wantedBy = ["multi-user.target"];
      requires = ["ai-usage-schema.service"];
      after = ["ai-usage-schema.service" "network-online.target" "systemd-tmpfiles-setup.service"];
      wants = ["network-online.target"];
      unitConfig.RequiresMountsFor = ["/srv/disks/projects"];
      restartTriggers = [template config.age.secrets.ai-proxy-client-key.file config.age.secrets.ai-proxy-openrouter-key.file config.age.secrets.ai-proxy-codex-auth.file config.age.secrets.ai-proxy-antigravity-auth.file];
      serviceConfig =
        hardening
        // {
          User = "ai-proxy";
          WorkingDirectory = root;
          LoadCredential = [
            "client-key:${config.age.secrets.ai-proxy-client-key.path}"
            "openrouter-key:${config.age.secrets.ai-proxy-openrouter-key.path}"
            "codex-auth:${config.age.secrets.ai-proxy-codex-auth.path}"
            "antigravity-auth:${config.age.secrets.ai-proxy-antigravity-auth.path}"
          ];
          ExecStartPre = "${pkgs.python3}/bin/python3 ${source}/render_proxy.py ${template} ${root}/config.yaml";
          ExecStart = "${pkgs.cli-proxy-api-plus-capture}/bin/cli-proxy-api-plus -config ${root}/config.yaml";
          Restart = "on-failure";
          RestartSec = 5;
        };
    };
    systemd.services.ai-usage-ingest = {
      description = "Archive all CLIProxy captures in ClickHouse";
      requires = ["ai-usage-schema.service"];
      after = ["ai-usage-schema.service"];
      unitConfig.RequiresMountsFor = ["/srv/disks/projects"];
      serviceConfig =
        hardening
        // {
          Type = "oneshot";
          User = "ai-proxy";
          EnvironmentFile = databaseEnv;
          ExecStart = "${pkgs.python3}/bin/python3 ${source}/ingest.py collect";
        };
    };
    systemd.timers.ai-usage-ingest = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "30s";
        OnUnitInactiveSec = "10s";
      };
    };
    security.acme.certs.${domain} = {
      extraLegoFlags = ["--dns.propagation.wait" "30s"];
      group = "nginx";
      reloadServices = ["nginx.service"];
    };
    services.nginx.virtualHosts.${domain} = {
      forceSSL = true;
      useACMEHost = domain;
      extraConfig = ''
        allow 127.0.0.1;
        allow ::1;
        allow 192.168.50.0/24;
        allow 192.168.111.0/24;
        allow 2a02:1810:515:c680::/64;
        allow 2a02:1810:515:c682::/64;
        allow 100.64.0.0/10;
        allow fd7a:115c:a1e0::/48;
        deny all;
        access_log off;
        client_max_body_size 0;
      '';
      locations."/" = {
        proxyPass = "http://127.0.0.1:8317";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_buffering off;
          proxy_request_buffering off;
          proxy_read_timeout 24h;
          proxy_send_timeout 24h;
        '';
      };
      locations."^~ /v0/management/".extraConfig = "return 404;";
    };
    # Cognee keeps its existing OpenRouter model, but inference now uses the gateway.
    virtualisation.oci-containers.containers.cognee = {
      environment = {
        LLM_ENDPOINT = lib.mkForce "http://127.0.0.1:8317/v1";
        LLM_MODEL = lib.mkForce "openai/openrouter/glm-5.3-flash";
      };
      environmentFiles = lib.mkAfter ["/run/ai-proxy-cognee/client.env"];
    };
    systemd.services.podman-cognee = {
      requires = ["cli-proxy-api-plus.service" "ai-proxy-cognee-env.service"];
      after = ["cli-proxy-api-plus.service" "ai-proxy-cognee-env.service"];
    };
  };
}
