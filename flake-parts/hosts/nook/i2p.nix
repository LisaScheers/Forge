{
  lib,
  pkgs,
  ...
}: let
  consoleDomain = "i2p.local.bylisa.dev";
  consolePort = 7070;
  httpProxyPort = 4444;
  socksProxyPort = 4447;
  routerPort = 27655;
  certificates = "${pkgs.i2pd.src}/contrib/certificates";
  proxyErrorPage = import ./_nginx-error-page.nix {inherit pkgs;};
in {
  networking.firewall = {
    allowedTCPPorts = [
      routerPort
    ];
    allowedUDPPorts = [routerPort];
  };

  services.cloudflare-dyndns.domains = [consoleDomain];

  security.acme.certs.${consoleDomain} = {
    extraLegoFlags = [
      "--dns.propagation-wait"
      "30s"
    ];
    group = "nginx";
    reloadServices = ["nginx.service"];
  };

  systemd.tmpfiles.rules = [
    "L+ /var/lib/i2pd/certificates - - - - ${certificates}"
  ];

  services.i2pd = {
    enable = true;
    logLevel = "warn";
    port = routerPort;
    share = 80;
    notransit = true;

    proto = {
      http = {
        enable = true;
        address = "127.0.0.1";
        port = consolePort;
        hostname = consoleDomain;
        strictHeaders = true;
      };
      httpProxy = {
        enable = true;
        address = "127.0.0.1";
        port = httpProxyPort;
      };
      socksProxy = {
        enable = true;
        address = "127.0.0.1";
        port = socksProxyPort;
      };
    };
  };

  systemd.services.i2pd = {
    after = ["network-online.target"];
    wants = ["network-online.target"];
  };

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    virtualHosts.${consoleDomain} = lib.mkMerge [
      proxyErrorPage
      {
        forceSSL = true;
        useACMEHost = consoleDomain;
        extraConfig = ''
          allow 192.168.50.0/24;
          allow 192.168.111.0/24;
          allow 2a02:1810:515:c682::/64;
          allow 2a02:1810:515:c680::/64;
          allow 100.64.0.0/10;
          allow fd7a:115c:a1e0::/48;
          allow 127.0.0.1;
          allow ::1;
          deny all;
        '';
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString consolePort}";
          proxyWebsockets = true;
        };
      }
    ];
  };
}
