{config, ...}: let
  pdsHostname = "bylisa.dev";
in {
  services.bluesky-pds = {
    enable = true;
    settings = {
      PDS_HOSTNAME = pdsHostname;
      PDS_PORT = 4000;
    };
    pdsadmin = {
      enable = true;
    };
    environmentFiles = [
      config.age.secrets.bluesky-pds-env.path
    ];
  };

  age.secrets = {
    bluesky-pds-env = {
      file = ../../agenix/secrets/atlas/bluesky-pds-env.age;
      owner = "root";
      group = "root";
      mode = "0400";
    };
    atlas-cloudflare-dns-api-token = {
      file = ../../agenix/secrets/atlas/cf-api-token.age;
      owner = config.users.users.acme.name;
      group = config.users.groups.acme.name;
      mode = "0400";
    };
  };
  # virtual host for bluesky
  services.nginx.virtualHosts = {
    ${config.services.bluesky-pds.settings.PDS_HOSTNAME} = {
      locations = {
        "/" = {
          proxyPass = "http://[::1]:${toString config.services.bluesky-pds.settings.PDS_PORT}";
          proxyWebsockets = true;
        };
      };
      forceSSL = true;
      enableACME = true;
    };
    "*.${pdsHostname}" = {
      locations = {
        "/" = {
          proxyPass = "http://[::1]:${toString config.services.bluesky-pds.settings.PDS_PORT}";
          proxyWebsockets = true;
        };
      };
      addSSL = true;
      useACMEHost = "wildcard.${pdsHostname}";
    };
  };

  security.acme.certs."wildcard.${pdsHostname}" = {
    dnsProvider = "cloudflare";
    dnsResolver = "1.1.1.1:53";
    environmentFile = config.age.secrets.atlas-cloudflare-dns-api-token.path;
    domain = "*.${pdsHostname}";
    group = config.users.groups.nginx.name;
    webroot = null;
  };

  systemd.services.bluesky-pds.restartTriggers = [../../agenix/secrets/atlas/bluesky-pds-env.age];
}
