{
  lib,
  pkgs,
  ...
}: let
  hostAddress = "192.168.111.2";
  hostIpv6Address = "2a02:1810:515:c680:f22f:74ff:fe1d:7b9b";
  lanIpv6Prefix = "2a02:1810:515:c680::/64";
  clientIpv6Prefix = "2a02:1810:515:c682::/64";
  upstreamAddress = "2a06:98c1:54::756a";
  upstreamTlsName = "nj004b71mp.cloudflare-gateway.com";
  localNames = [
    "home-server.local.bylisa.dev."
    "i2p.local.bylisa.dev."
    "dns.local.bylisa.dev."
    "grafana.local.bylisa.dev."
    "ha.local.bylisa.dev."
    "jellyfin.local.bylisa.dev."
    "media.local.bylisa.dev."
    "neo4j.local.bylisa.dev."
    "prowlarr.local.bylisa.dev."
    "radarr.local.bylisa.dev."
    "second-life-cache.local.bylisa.dev."
    "sl-cache.local.bylisa.dev."
    "sonarr.local.bylisa.dev."
    "transmission.local.bylisa.dev."
  ];
  localRecords =
    map (record: ''"${record}"'')
    (map (name: "${name} 300 IN A ${hostAddress}") localNames
      ++ map (name: "${name} 300 IN AAAA ${hostIpv6Address}") localNames);
  localPtrRecords = [
    ''"${hostAddress} home-server.local.bylisa.dev."''
    ''"${hostIpv6Address} home-server.local.bylisa.dev."''
  ];
in {
  networking.firewall = {
    allowedTCPPorts = [53];
    allowedUDPPorts = [53];
  };

  systemd.network.networks."10-uplink" = {
    dns = lib.mkForce ["127.0.0.1"];
    ipv6AcceptRAConfig.UseDNS = lib.mkForce false;
  };

  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNS = "127.0.0.1";
      DNSOverTLS = "false";
      DNSSEC = "false";
      FallbackDNS = "";
      Domains = "~.";
    };
  };

  services.unbound = {
    enable = true;
    checkconf = true;
    localControlSocketPath = "/run/unbound/unbound.ctl";
    resolveLocalQueries = false;
    settings = {
      server = {
        access-control = [
          "127.0.0.0/8 allow"
          "::1/128 allow"
          "192.168.50.0/24 allow"
          "192.168.111.0/24 allow"
          "${clientIpv6Prefix} allow"
          "${lanIpv6Prefix} allow"
          "100.64.0.0/10 allow"
          "fd7a:115c:a1e0::/48 allow"
        ];
        do-ip4 = true;
        do-ip6 = true;
        do-tcp = true;
        do-udp = true;
        extended-statistics = true;
        hide-identity = true;
        hide-version = true;
        interface = [
          "127.0.0.1"
          "::1"
          hostAddress
          "::"
        ];
        local-data = localRecords;
        local-data-ptr = localPtrRecords;
        local-zone = [
          "local.bylisa.dev. static"
          "111.168.192.in-addr.arpa. static"
        ];
        prefetch = true;
        qname-minimisation = true;
        statistics-cumulative = true;
        tls-cert-bundle = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      };
      forward-zone = [
        {
          name = ".";
          forward-tls-upstream = true;
          forward-addr = [
            "${upstreamAddress}@853#${upstreamTlsName}"
          ];
        }
      ];
    };
  };

  systemd.services.prometheus-unbound-exporter = {
    description = "Prometheus exporter for Unbound DNS resolver";
    wantedBy = ["multi-user.target"];
    after = ["unbound.service"];
    requires = ["unbound.service"];
    serviceConfig = {
      User = "unbound";
      Group = "unbound";
      ExecStart = "${pkgs.prometheus-unbound-exporter}/bin/unbound_exporter -web.listen-address=127.0.0.1:9167 -unbound.host=unix:///run/unbound/unbound.ctl";
      Restart = "always";
      RestartSec = "5s";
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
    };
  };
}
