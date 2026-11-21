{
  nixos.nook = {config, ...}: {
    # ha.bylisa.dev follows Nook's public address and has its own certificate;
    # the ACME account and DNS challenge come from nginx/acme.nix.
    services.cloudflare-dyndns = {
      enable = true;
      apiTokenFile = config.age.secrets.cloudflare-dns-api-token.path;
      domains = [
        "ha.bylisa.dev"
        "ha.local.bylisa.dev"
      ];
      ipv4 = true;
      ipv6 = true;
      proxied = false;
    };

    security.acme.certs."ha.bylisa.dev" = {
      extraDomainNames = ["ha.local.bylisa.dev"];
      extraLegoFlags = [
        "--dns.propagation.wait"
        "30s"
      ];
      group = "nginx";
      reloadServices = ["nginx.service"];
    };

    systemd.services.cloudflare-dyndns = {
      # Activation stops Unbound before restarting the updater. Wait for the
      # local resolver so IP discovery does not fail during a system switch.
      after = ["unbound.service"];
      wants = ["unbound.service"];
      restartTriggers = [config.age.secrets.cloudflare-dns-api-token.file];
    };
  };
}
