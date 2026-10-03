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
    d3 = pkgs.fetchurl {
      url = "https://d3js.org/d3.v7.min.js";
      hash = "sha256-8glLv2FBs1lyLE/kVOtsSw8OQswQzHr5IfwVj864ZTk=";
    };
    # The image's Ladybug 0.19 corrupts WAL records larger than 4 KiB.
    # 0.21 fixes both writer and reader: LadybugDB/ladybug#959.
    ladybugWheel = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/20/b6/50046dcdd7774b830b4572d79215cda11f6024d9b2815e5a1b68220edaee/ladybug-0.21.0-cp312-cp312-manylinux_2_27_x86_64.manylinux_2_28_x86_64.whl";
      sha256 = "27a85426bbb6ec082716d1225c9d02ddc37da45a135ddc9cb518c242ad56d280";
    };
    ladybugJson = pkgs.fetchurl {
      url = "https://extension.ladybugdb.com/v0.21.0/linux_amd64/json/libjson.lbug_extension";
      sha256 = "a5240f112f05c15f87108be3d03dea7a296b0f8bd66fc95229c987f0cc73a9dc";
    };
    ladybug = pkgs.runCommand "cognee-ladybug-0.21.0" {nativeBuildInputs = [pkgs.unzip];} ''
      mkdir -p "$out/json/linux_amd64"
      unzip -q ${ladybugWheel} -d "$out"
      cp ${ladybugJson} "$out/json/linux_amd64/libjson.lbug_extension"
    '';
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
      "d ${storageRoot}/email-import 0700 cognee cognee - -"
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
          PYTHONPATH = "/etc/cognee-python";
          LLM_PROVIDER = "custom";
          LLM_MODEL = "openrouter/z-ai/glm-5.3-flash";
          LLM_ENDPOINT = "https://openrouter.ai/api/v1";
          LLM_MAX_COMPLETION_TOKENS = "16384";
          STRUCTURED_OUTPUT_FRAMEWORK = "litellm_native";
          EMBEDDING_PROVIDER = "fastembed";
          EMBEDDING_MODEL = "sentence-transformers/all-MiniLM-L6-v2";
          EMBEDDING_DIMENSIONS = "384";
          EMBEDDING_MAX_COMPLETION_TOKENS = "256";
          FASTEMBED_THREADS = "2";
          # Match graph queries and numeric layouts to the container CPU quota.
          KUZU_NUM_THREADS = "2";
          # Cognee defaults to a 32 GiB pool, exceeding this 6 GiB container.
          KUZU_BUFFER_POOL_SIZE = "1073741824";
          OMP_NUM_THREADS = "2";
          OPENBLAS_NUM_THREADS = "2";
          MKL_NUM_THREADS = "2";
          LLM_RATE_LIMIT_REQUESTS = "10";
          ENABLE_BACKEND_ACCESS_CONTROL = "true";
          REQUIRE_AUTHENTICATION = "true";
          HASH_API_KEY = "true";
          ACCEPT_LOCAL_FILE_PATH = "false";
          COGNEE_ALLOWED_LOCAL_FILE_ROOTS = "/cognee-storage/data";
          ALLOW_HTTP_REQUESTS = "false";
          # Original email dumps remain available, but only their cleaned local
          # index is processed. Never send the archive through paid extraction.
          COGNEE_EMAIL_ARCHIVE_IDS = "/cognee-email/archive-source-ids.json";
          CORS_ALLOWED_ORIGINS = "https://${domain}";
          TELEMETRY_DISABLED = "1";
        };
        volumes = [
          "${storageRoot}/system:/cognee-storage/system"
          "${storageRoot}/data:/cognee-storage/data"
          "${storageRoot}/cache:/cognee-cache"
          "${source}/api.py:/etc/cognee-api.py:ro"
          "${source}/email_index.py:/etc/email_index.py:ro"
          "${storageRoot}/email-import:/cognee-email:ro"
          "${ladybug}:/etc/cognee-python:ro"
          "${ladybug}/json:/app/cognee_db_workers/ladybug_extensions/v0.21.0:ro"
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
          "${source}/email_recall.py:/etc/email_recall.py:ro"
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
      after = ["systemd-tmpfiles-setup.service"];
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

    systemd.services.cognee-graph = {
      description = "Private Cognee graph viewer";
      wantedBy = ["multi-user.target"];
      requires = ["cognee-bootstrap.service"];
      after = ["cognee-bootstrap.service"];
      environment.COGNEE_GRAPH_D3 = "${d3}";
      serviceConfig = {
        ExecStart = "${python}/bin/python3 ${source}/graph.py";
        EnvironmentFile = mcpKeyFile;
        DynamicUser = true;
        Group = "nginx";
        RuntimeDirectory = "cognee-graph";
        RuntimeDirectoryMode = "0750";
        UMask = "0007";
        Restart = "on-failure";
        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        RestrictAddressFamilies = ["AF_UNIX" "AF_INET"];
        IPAddressDeny = "any";
        IPAddressAllow = "localhost";
        MemoryMax = "256M";
        TasksMax = 32;
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
        proxy_buffers 8 16k;
        proxy_buffer_size 32k;
      '';
      locations."= /graph".extraConfig = "return 302 /graph/;";
      locations."^~ /graph/" = {
        proxyPass = "http://unix:/run/cognee-graph/http.sock:";
        extraConfig = ''
          auth_request /outpost.goauthentik.io/auth/nginx;
          auth_request_set $graph_cookie $upstream_http_set_cookie;
          add_header Set-Cookie $graph_cookie always;
          error_page 401 = @graph_signin;
          proxy_set_header Authorization "";
          proxy_set_header X-Api-Key "";
          proxy_set_header Cookie "";
          proxy_read_timeout 180s;
          proxy_buffering off;
        '';
      };
      locations."@graph_signin".extraConfig = ''
        internal;
        add_header Set-Cookie $graph_cookie always;
        return 302 /outpost.goauthentik.io/start?rd=https://${domain}/graph/;
      '';
      locations."^~ /outpost.goauthentik.io/" = {
        proxyPass = "https://auth.bylisa.dev";
        recommendedProxySettings = false;
        extraConfig = ''
          proxy_ssl_server_name on;
          proxy_ssl_name auth.bylisa.dev;
          proxy_ssl_verify on;
          proxy_ssl_verify_depth 3;
          proxy_ssl_trusted_certificate ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt;
          proxy_set_header Host auth.bylisa.dev;
          proxy_set_header X-Forwarded-Host ${domain};
          proxy_set_header X-Forwarded-Proto https;
          proxy_set_header X-Original-URL https://${domain}$request_uri;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $remote_addr;
          proxy_set_header Authorization "";
          proxy_pass_request_body off;
          proxy_set_header Content-Length "";
        '';
      };
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
