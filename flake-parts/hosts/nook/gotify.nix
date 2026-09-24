{config, ...}: let
  errorPage = config.forge.nginxErrorPage;
in {
  forge.modules.nixos.nook = {
    config,
    lib,
    pkgs,
    ...
  }: let
    domain = "gotify.bylisa.dev";
    gotifyAddress = "127.0.0.1";
    gotifyPort = 8097;
    proxyErrorPage = errorPage {inherit pkgs;};
    authentikPluginSource = pkgs.fetchFromGitHub {
      owner = "ckocyigit";
      repo = "gotify-authentik-plugin";
      rev = "2c1671905d7dca0e6081c1e53b2a3a97e71ed04c";
      hash = "sha256-Y7x/PSLobsYecLVtSBcrbzhyxHCrTgekwKbvCi3/MTo=";
    };
    # Go plugins must share the server's toolchain and dependency versions.
    # Build inside its module using the already-vendored server dependencies.
    gotifyWithAuthentik = pkgs.gotify-server.overrideAttrs (old: {
      postBuild =
        (old.postBuild or "")
        + ''
          mkdir -p authentik-plugin
          cp ${authentikPluginSource}/*.go authentik-plugin/
          go test ./authentik-plugin
          go build -buildmode=plugin -ldflags="-s -w -buildid=" \
            -o authentik.so ./authentik-plugin
        '';
      postInstall =
        (old.postInstall or "")
        + ''
          install -Dm444 authentik.so "$out/lib/gotify/plugins/authentik.so"
        '';
      nativeInstallCheckInputs = [pkgs.curl pkgs.jq];
      doInstallCheck = true;
      installCheckPhase = ''
        runHook preInstallCheck
        # A successful compile alone does not prove Go's plugin ABI matches.
        cd "$(mktemp -d)"
        export GOTIFY_PLUGINSDIR="$out/lib/gotify/plugins"
        export GOTIFY_SERVER_LISTENADDR=127.0.0.1
        export GOTIFY_SERVER_PORT=18080
        export GOTIFY_DEFAULTUSER_PASS=plugin-test
        "$out/bin/server" >server.log 2>&1 &
        server_pid=$!
        trap 'kill "$server_pid"; wait "$server_pid" || true' EXIT
        curl --silent --show-error --fail --retry 20 --retry-connrefused \
          --retry-delay 1 --retry-max-time 30 \
          --user admin:plugin-test http://127.0.0.1:18080/plugin >plugins.json \
          || { cat server.log; exit 1; }
        jq -e 'any(.[]; .modulePath == "github.com/ckocyigit/gotify-authentik-plugin")' plugins.json \
          || { cat server.log; exit 1; }
        runHook postInstallCheck
      '';
    });
  in {
    age.secrets.gotify-oidc-env = {
      file = ../../agenix/secrets/shared/gotify-oidc-env.age;
      owner = "root";
      group = "root";
      mode = "0400";
    };
    age.secrets.gotify-env = {
      file = ../../agenix/secrets/nook/gotify-env.age;
      owner = "root";
      group = "root";
      mode = "0400";
    };

    services.cloudflare-dyndns.domains = [domain];

    security.acme.certs.${domain} = {
      extraLegoFlags = [
        "--dns.propagation-wait"
        "30s"
      ];
      group = "nginx";
      reloadServices = ["nginx.service"];
    };

    services.gotify = {
      enable = true;
      package = gotifyWithAuthentik;
      environment = {
        GOTIFY_DATABASE_CONNECTION = "data/gotify.db";
        GOTIFY_DATABASE_DIALECT = "sqlite3";
        GOTIFY_OIDC_ENABLED = "true";
        GOTIFY_OIDC_ISSUER = "https://auth.bylisa.dev/application/o/gotify/";
        GOTIFY_OIDC_CLIENTID = "gotify";
        GOTIFY_OIDC_REDIRECTURL = "https://${domain}/auth/oidc/callback";
        GOTIFY_OIDC_IDP_NAME = "Authentik";
        GOTIFY_OIDC_USERNAMECLAIM = "preferred_username";
        GOTIFY_OIDC_SCOPES = "openid,profile,email";
        # Reuse the Authentik session instead of forcing a fresh login.
        GOTIFY_OIDC_PROMPT = "";
        GOTIFY_OIDC_AUTOREGISTER = "true";
        GOTIFY_OIDC_LINK_BY_USERNAME = "false";
        GOTIFY_OIDC_GROUPS_CLAIM = "groups";
        GOTIFY_OIDC_GROUPS_USER = "authentik Admins";
        GOTIFY_OIDC_GROUPS_ADMIN = "authentik Admins";
        GOTIFY_PLUGINSDIR = "${gotifyWithAuthentik}/lib/gotify/plugins";
        GOTIFY_REGISTRATION = "false";
        GOTIFY_SERVER_LISTENADDR = gotifyAddress;
        GOTIFY_SERVER_PORT = gotifyPort;
        GOTIFY_SERVER_SSL_ENABLED = "false";
        GOTIFY_SERVER_STREAM_ALLOWEDORIGINS = ''["https://${domain}"]'';
        GOTIFY_UPLOADEDIMAGESDIR = "data/images";
      };
      environmentFiles = [
        config.age.secrets.gotify-env.path
        config.age.secrets.gotify-oidc-env.path
      ];
    };

    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      upstreams.gotify.servers."${gotifyAddress}:${toString gotifyPort}" = {};
      virtualHosts.${domain} = lib.mkMerge [
        proxyErrorPage
        {
          forceSSL = true;
          useACMEHost = domain;
          locations."/" = {
            proxyPass = "http://gotify";
            proxyWebsockets = true;
          };
        }
      ];
    };

    systemd.services.gotify-server.restartTriggers = [
      ../../agenix/secrets/nook/gotify-env.age
      ../../agenix/secrets/shared/gotify-oidc-env.age
    ];
  };
}
