{
  config,
  pkgs,
  ...
}: let
  hostName = "plans.bylisa.dev";
  port = 8787;
  secretFile = config.age.secrets.postplan-env.path;
in {
  users.groups.postplan = {};
  users.users.postplan = {
    isSystemUser = true;
    group = "postplan";
  };

  age.secrets.postplan-env = {
    file = ../../agenix/secrets/shared/postplan-env.age;
    owner = "root";
    group = "postplan";
    mode = "0440";
  };

  services.postgresql = {
    enable = true;
    ensureDatabases = ["postplan"];
    ensureUsers = [
      {
        name = "postplan";
        ensureDBOwnership = true;
      }
    ];
  };

  systemd.services.postplan = {
    description = "PostPlan static HTML draft publishing";
    wantedBy = ["multi-user.target"];
    wants = ["network-online.target"];
    after = ["network-online.target" "postgresql.service"];
    requires = ["postgresql.service"];
    environment = {
      PORT = toString port;
      DATABASE_URL = "postgresql:///postplan?host=/run/postgresql";
      POSTPLAN_PUBLIC_BASE_URL = "https://${hostName}";
      POSTPLAN_STORAGE_DIR = "/var/lib/postplan/objects";
      MAX_HTML_BYTES = toString (512 * 1024);
      AUTHENTIK_BASE_URL = "https://auth.bylisa.dev";
      AUTHENTIK_ISSUER_URL = "https://auth.bylisa.dev/application/o/postplan/";
      AUTHENTIK_CLIENT_ID = "postplan";
      NODE_ENV = "production";
    };
    serviceConfig = {
      ExecStart = "${pkgs.postplan-selfhosted}/bin/postplan-server";
      EnvironmentFile = secretFile;
      User = "postplan";
      Group = "postplan";
      StateDirectory = "postplan";
      StateDirectoryMode = "0700";
      UMask = "0077";
      Restart = "on-failure";
      RestartSec = 2;

      CapabilityBoundingSet = "";
      LockPersonality = true;
      NoNewPrivileges = true;
      PrivateDevices = true;
      PrivateTmp = true;
      ProtectClock = true;
      ProtectControlGroups = true;
      ProtectHome = true;
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectSystem = "strict";
      RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6"];
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      SystemCallArchitectures = "native";
    };
    restartTriggers = [
      pkgs.postplan-selfhosted
      ../../agenix/secrets/shared/postplan-env.age
    ];
  };

  services.nginx.virtualHosts.${hostName} = {
    enableACME = true;
    forceSSL = true;
    extraConfig = ''
      client_max_body_size 2m;
    '';
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString port}";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_request_buffering on;
      '';
    };
  };
}
