{
  config,
  lib,
  pkgs,
  ...
}: let
  domain = "gotify.bylisa.dev";
  gotifyAddress = "127.0.0.1";
  gotifyPort = 8097;
  proxyErrorPage = import ./_nginx-error-page.nix {inherit pkgs;};
in {
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
    environment = {
      GOTIFY_DATABASE_CONNECTION = "data/gotify.db";
      GOTIFY_DATABASE_DIALECT = "sqlite3";
      GOTIFY_REGISTRATION = "false";
      GOTIFY_SERVER_LISTENADDR = gotifyAddress;
      GOTIFY_SERVER_PORT = gotifyPort;
      GOTIFY_SERVER_SSL_ENABLED = "false";
      GOTIFY_SERVER_STREAM_ALLOWEDORIGINS = ''["https://${domain}"]'';
      GOTIFY_UPLOADEDIMAGESDIR = "data/images";
    };
    environmentFiles = [config.age.secrets.gotify-env.path];
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

  systemd.services.gotify-server.restartTriggers = [../../agenix/secrets/nook/gotify-env.age];
}
