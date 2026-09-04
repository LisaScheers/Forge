{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.matrix;
  fqdn = "${cfg.subDomain}.${cfg.rootDomain}";
  baseUrl = "https://${fqdn}";
  clientConfig = {
    "m.homeserver".base_url = baseUrl;
    "m.identity_server".base_url = baseUrl;
    "org.matrix.msc3575.proxy".url = baseUrl;
    "org.matrix.msc4143.rtc_foci" = [
      {
        type = "livekit";
        livekit_service_url = "https://${fqdn}/livekit/jwt";
      }
    ];
  };
  serverConfig = {
    "m.server" = "${fqdn}:443";
  };
  mkWellKnown = data: ''
    default_type application/json;
    add_header Access-Control-Allow-Origin *;
    return 200 '${builtins.toJSON data}';
  '';
in {
  networking = lib.mkIf (cfg.enable) {
    firewall.allowedTCPPorts = [
      80
      443
    ];
  };

  services.postgresql = lib.mkIf (cfg.enable) {
    enable = true;
    ensureUsers = [
      {
        name = "root";
        ensureClauses = {
          superuser = true;
          createrole = true;
          createdb = true;
        };
      }
      {
        name = "matrix-synapse";
        ensureClauses = {
          login = true;
        };
        ensureDBOwnership = true;
      }
    ];
    ensureDatabases = [
      "matrix-synapse"
    ];
  };

  services.nginx = lib.mkIf (cfg.enable) {
    enable = true;
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;
    recommendedProxySettings = true;
    virtualHosts = {
      "${config.networking.domain}" = {
        enableACME = true;
        forceSSL = true;
        locations."= /.well-known/matrix/server".extraConfig = mkWellKnown serverConfig;
        locations."= /.well-known/matrix/client".extraConfig = mkWellKnown clientConfig;
      };
      "${fqdn}" = {
        enableACME = true;
        forceSSL = true;

        # This section is not needed if the server_name of matrix-synapse is equal to
        # the domain (i.e. example.org from @foo:example.org) and the federation port
        # is 8448.
        # Further reference can be found in the docs about delegation under
        # https://element-hq.github.io/synapse/latest/delegate.html
        locations."= /.well-known/matrix/server".extraConfig = mkWellKnown serverConfig;
        # This is usually needed for homeserver discovery (from e.g. other Matrix clients).
        # Further reference can be found in the upstream docs at
        # https://spec.matrix.org/latest/client-server-api/#getwell-knownmatrixclient
        locations."= /.well-known/matrix/client".extraConfig = mkWellKnown clientConfig;

        # The root location is intentionally left to another service sharing this
        # virtual host (currently Bluesky PDS). Matrix owns only its explicit paths.
        # Forward all Matrix API calls to the synapse Matrix homeserver. A trailing slash
        # *must not* be used here.
        locations."/_matrix" = {
          proxyPass = "http://[::1]:8008";
          #extraConfig = ''
          #  add_header Access-Control-Allow-Origin *;
          #'';
        };
        # Forward requests for e.g. SSO and password-resets.
        locations."/_synapse/client" = {
          proxyPass = "http://[::1]:8008";
          #extraConfig = ''
          #  add_header Access-Control-Allow-Origin *;
          #'';
        };
        locations."/_synapse/admin" = {
          proxyPass = "http://[::1]:8008";
          #extraConfig = ''
          #  add_header Access-Control-Allow-Origin *;
          #'';
          # block all access excep from ip
          extraConfig = ''
            allow 84.198.125.249;
            deny all;
          '';
        };
      };
      "element.${config.networking.domain}" = {
        enableACME = true;
        forceSSL = true;
        serverAliases = ["element.${config.networking.domain}"];

        root = pkgs.element-web.override {
          conf = {
            default_server_config = clientConfig; # see `clientConfig` from the snippet above.
          };
        };
      };
    };
  };

  services.matrix-synapse = lib.mkIf (cfg.enable) {
    enable = true;
    settings.server_name = config.networking.domain;
    # The public base URL value must match the `base_url` value set in `clientConfig` above.
    # The default value here is based on `server_name`, so if your `server_name` is different
    # from the value of `fqdn` above, you will likely run into some mismatched domain names
    # in client applications.
    settings.public_baseurl = baseUrl;
    settings.listeners = [
      {
        port = 8008;
        bind_addresses = ["::1"];
        type = "http";
        tls = false;
        x_forwarded = true;
        resources = [
          {
            names = [
              "client"
              "federation"
            ];
            compress = true;
          }
        ];
      }
    ];
    settings.registration_shared_secret_path = cfg.registrationSecretFile;
  };
}
