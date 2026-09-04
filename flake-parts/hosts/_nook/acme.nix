{config, ...}: {
  # cloudflare-dyndns imports this root-only source through systemd
  # LoadCredential before entering its DynamicUser sandbox.
  age.secrets.cloudflare-dns-api-token = {
    file = ../../agenix/secrets/nook/cloudflare-dns-api-token.age;
    owner = "root";
    group = "root";
    mode = "0400";
  };

  services.cloudflare-dyndns = {
    enable = true;
    apiTokenFile = config.age.secrets.cloudflare-dns-api-token.path;
    domains = [
      "grafana.bylisa.dev"
      "grafana.local.bylisa.dev"
      "ha.bylisa.dev"
      "ha.local.bylisa.dev"
    ];
    ipv4 = true;
    ipv6 = true;
    proxied = false;
  };

  security.acme = {
    acceptTerms = true;
    certs."grafana.bylisa.dev" = {
      extraDomainNames = ["grafana.local.bylisa.dev"];
      extraLegoFlags = [
        "--dns.propagation-wait"
        "30s"
      ];
      group = "nginx";
      reloadServices = ["nginx.service"];
    };
    certs."ha.bylisa.dev" = {
      extraDomainNames = ["ha.local.bylisa.dev"];
      extraLegoFlags = [
        "--dns.propagation-wait"
        "30s"
      ];
      group = "nginx";
      reloadServices = ["nginx.service"];
    };
    defaults = {
      dnsProvider = "cloudflare";
      credentialFiles."CF_DNS_API_TOKEN_FILE" =
        config.age.secrets.cloudflare-dns-api-token.path;
    };
  };

  systemd.services.cloudflare-dyndns.restartTriggers = [../../agenix/secrets/nook/cloudflare-dns-api-token.age];
}
