{
  perSystem = {pkgs, ...}: let
    python = pkgs.python3.withPackages (ps: [ps.aiohttp ps.pyjwt ps.cryptography]);
  in {
    packages.cognee-openai-login = pkgs.writeShellApplication {
      name = "cognee-openai-login";
      text = ''
        exec ${python}/bin/python3 ${../../../services/cognee/openai_plan.py} login \
          --host-id urn:uuid:128b7566-1f4a-4f61-9df0-94a3d04f2389 \
          --credentials "''${XDG_STATE_HOME:-$HOME/.local/state}/forge-cognee/nook-openai.json" "$@"
      '';
    };
    checks.cognee-openai-plan = pkgs.runCommand "cognee-openai-plan-tests" {} ''
      ${python}/bin/python3 -B -m unittest discover -s ${../../../services/cognee} -v
      touch "$out"
    '';
  };
  forge.modules.nixos.nook = {
    config,
    pkgs,
    ...
  }: let
    storageRoot = "/srv/disks/projects/cognee";
    domain = "cognee.local.bylisa.dev";
    python = pkgs.python3.withPackages (ps: [ps.aiohttp ps.pyjwt ps.cryptography]);
    source = ../../../services/cognee;
    backendEnvironment = config.age.secrets.cognee-backend-env.path;
    oidcEnvironment = config.age.secrets.cognee-oidc-env.path;
    mcpKeyFile = "${storageRoot}/credentials/mcp.env";
    containerOptions = [
      "--network=host"
      "--cap-drop=ALL"
      "--security-opt=no-new-privileges"
      "--pids-limit=256"
      "--cpus=2"
      "--log-driver=journald"
      "--stop-timeout=30"
      # Podman creates failed transient units for expected startup checks,
      # which triggers deploy-rs rollback. ExecStartPost gates readiness instead.
      "--health-interval=disable"
    ];
  in {
    age.secrets = {
      cognee-backend-env = {
        file = ../../agenix/secrets/nook/cognee-backend-env.age;
        mode = "0400";
      };
      cognee-oidc-env = {
        file = ../../agenix/secrets/shared/cognee-oidc-env.age;
        mode = "0400";
      };
    };

    # The published images use uid 1000 (Lisa on Nook). Override it with an
    # explicit service identity so memory is not owned by a login account.
    users.users.cognee = {
      isSystemUser = true;
      uid = 970;
      group = "cognee";
    };
    users.groups.cognee.gid = 970;
    systemd.tmpfiles.rules = [
      "d ${storageRoot} 0711 root root - -"
      "d ${storageRoot}/system 0700 cognee cognee - -"
      "d ${storageRoot}/data 0700 cognee cognee - -"
      "d ${storageRoot}/cache 0700 cognee cognee - -"
      "d ${storageRoot}/mcp 0700 cognee cognee - -"
      "d ${storageRoot}/credentials 0700 root root - -"
      "d ${storageRoot}/openai 0700 root root - -"
      "d ${storageRoot}/containers 0700 root root - -"
    ];

    # Nook's system SSD has only 19 GiB free. Images and writable layers must
    # live on the data NVMe too, rather than consuming /var/lib/containers.
    virtualisation.podman.enable = true;
    virtualisation.containers.storage.settings.storage.graphroot = "${storageRoot}/containers";
    virtualisation.oci-containers = {
      backend = "podman";
      containers.cognee = {
        image = "docker.io/cognee/cognee@sha256:05ac5ca16f0308190e06771c35d9be0d666c313ad1deb587228ec26179f2336e";
        user = "970:970";
        environmentFiles = [backendEnvironment];
        environment = {
          ENV = "prod";
          BIND_ADDRESS = "127.0.0.1";
          HTTP_PORT = "8321";
          HOME = "/cognee-cache";
          XDG_CACHE_HOME = "/cognee-cache";
          HF_HOME = "/cognee-cache/huggingface";
          FASTEMBED_CACHE_PATH = "/cognee-cache/fastembed";
          SYSTEM_ROOT_DIRECTORY = "/cognee-storage/system";
          DATA_ROOT_DIRECTORY = "/cognee-storage/data";
          COGNEE_REPOS_DIR = "/cognee-cache/repos";
          DB_PROVIDER = "sqlite";
          VECTOR_DB_PROVIDER = "lancedb";
          GRAPH_DATABASE_PROVIDER = "kuzu";
          LLM_PROVIDER = "custom";
          LLM_MODEL = "openai/gpt-6-luna";
          LLM_ENDPOINT = "http://127.0.0.1:8320/v1";
          LLM_MAX_COMPLETION_TOKENS = "16384";
          STRUCTURED_OUTPUT_FRAMEWORK = "litellm_native";
          EMBEDDING_PROVIDER = "fastembed";
          EMBEDDING_MODEL = "sentence-transformers/all-MiniLM-L6-v2";
          EMBEDDING_DIMENSIONS = "384";
          EMBEDDING_MAX_COMPLETION_TOKENS = "256";
          LLM_RATE_LIMIT_REQUESTS = "10";
          ENABLE_BACKEND_ACCESS_CONTROL = "true";
          REQUIRE_AUTHENTICATION = "true";
          HASH_API_KEY = "true";
          ACCEPT_LOCAL_FILE_PATH = "false";
          COGNEE_ALLOWED_LOCAL_FILE_ROOTS = "/cognee-storage/data";
          ALLOW_HTTP_REQUESTS = "false";
          CORS_ALLOWED_ORIGINS = "https://${domain}";
          TELEMETRY_DISABLED = "1";
        };
        volumes = [
          "${storageRoot}/system:/cognee-storage/system"
          "${storageRoot}/data:/cognee-storage/data"
          "${storageRoot}/cache:/cognee-cache"
          "${source}/api.py:/etc/cognee-api.py:ro"
        ];
        cmd = ["/etc/cognee-api.py"];
        extraOptions =
          containerOptions
          ++ [
            "--memory=6g"
            "--entrypoint=/app/.venv/bin/python"
            "--health-cmd=python -c \"import urllib.request; urllib.request.urlopen('http://127.0.0.1:8321/health', timeout=5)\""
            "--health-start-period=120s"
          ];
      };
      containers.cognee-mcp = {
        image = "docker.io/cognee/cognee-mcp@sha256:240b49174b5dcf5906e8e5a6d46b24b947361866be93956032d7e88c0876bafa";
        user = "970:970";
        dependsOn = ["cognee"];
        environmentFiles = [oidcEnvironment mcpKeyFile];
        environment = {
          HOME = "/cognee-mcp";
          XDG_DATA_HOME = "/cognee-mcp";
          FASTMCP_HOME = "/cognee-mcp/fastmcp";
          COGNEE_MCP_AGENT_SCOPED = "false";
          MCP_ALLOWED_HOSTS = "${domain}:*";
          MCP_CORS_ALLOW_ORIGINS = "https://${domain}";
          TELEMETRY_DISABLED = "1";
        };
        volumes = [
          "${storageRoot}/mcp:/cognee-mcp"
          "${source}/mcp.py:/etc/cognee-mcp.py:ro"
        ];
        cmd = [
          "/etc/cognee-mcp.py"
          "--transport"
          "http"
          "--host"
          "127.0.0.1"
          "--port"
          "8322"
          # Avoid journaling OAuth callback codes and request URLs.
          "--log-level"
          "warning"
          "--api-url"
          "http://127.0.0.1:8321"
          "--api-auth-scheme"
          "x-api-key"
          "--no-migration"
          "--tool-mode"
          "all"
        ];
        extraOptions =
          containerOptions
          ++ [
            "--memory=2g"
            "--entrypoint=/app/.venv/bin/python"
            "--health-cmd=python -c \"import urllib.request; urllib.request.urlopen('http://127.0.0.1:8322/health', timeout=5)\""
            "--health-start-period=120s"
          ];
      };
    };

    systemd.services.cognee-openai-plan = {
      description = "Cognee ChatGPT plan adapter (GPT-6 Luna)";
      wantedBy = ["multi-user.target"];
      after = ["network-online.target"];
      wants = ["network-online.target"];
      unitConfig.RequiresMountsFor = storageRoot;
      serviceConfig = {
        ExecStart = "${python}/bin/python3 ${source}/openai_plan.py serve --credentials ${storageRoot}/openai/credentials.json";
        EnvironmentFile = backendEnvironment;
        Restart = "on-failure";
        RestartSec = 5;
        UMask = "0077";
        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ReadWritePaths = ["${storageRoot}/openai"];
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6"];
        MemoryMax = "256M";
      };
      restartTriggers = [../../agenix/secrets/nook/cognee-backend-env.age];
    };

    systemd.services.cognee-bootstrap = {
      description = "Provision Cognee's private MCP account";
      requires = ["podman-cognee.service"];
      after = ["podman-cognee.service"];
      unitConfig.RequiresMountsFor = storageRoot;
      environment = {COGNEE_MCP_KEY_FILE = mcpKeyFile;};
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${python}/bin/python3 ${source}/bootstrap.py";
        EnvironmentFile = backendEnvironment;
        UMask = "0077";
        TimeoutStartSec = 300;
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ReadWritePaths = ["${storageRoot}/credentials"];
      };
    };
    systemd.services.podman-cognee = {
      requires = ["cognee-openai-plan.service"];
      after = ["cognee-openai-plan.service" "systemd-tmpfiles-setup.service"];
      unitConfig.RequiresMountsFor = storageRoot;
      restartTriggers = [../../agenix/secrets/nook/cognee-backend-env.age];
      serviceConfig = {
        ExecStartPost = "${python}/bin/python3 ${source}/wait_health.py 8321";
      };
    };
    systemd.services.podman-cognee-mcp = {
      requires = ["cognee-bootstrap.service"];
      after = ["cognee-bootstrap.service"];
      unitConfig.RequiresMountsFor = storageRoot;
      restartTriggers = [../../agenix/secrets/shared/cognee-oidc-env.age];
      serviceConfig = {
        ExecStartPost = "${python}/bin/python3 ${source}/wait_health.py 8322";
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
        client_max_body_size 20m;
      '';
      locations."/" = {
        proxyPass = "http://127.0.0.1:8322";
        extraConfig = ''
          proxy_buffering off;
          proxy_read_timeout 600s;
        '';
      };
      locations."/api/" = {
        proxyPass = "http://127.0.0.1:8321";
        extraConfig = ''
          proxy_buffering off;
          proxy_read_timeout 600s;
        '';
      };
      # Account enrollment is local/SSH-only. Existing API-key users can use
      # the REST API; browser/MCP authorization is handled by Authentik.
      locations."= /api/v1/auth/register".extraConfig = "return 403;";
      locations."= /api/v1/auth/register/".extraConfig = "return 403;";
      locations."= /health" = {proxyPass = "http://127.0.0.1:8321/health";};
    };
  };
}
