{
  nixos.nook = {config, ...}: {
    # Nook's ACME account and Cloudflare DNS challenge, shared by every Nook
    # certificate. cloudflare-dyndns (home-assistant/dns.nix) imports this
    # root-only token through systemd LoadCredential before entering its
    # DynamicUser sandbox.
    age.secrets.cloudflare-dns-api-token = {
      file = ../../security/agenix/secrets/nook/cloudflare-dns-api-token.age;
      owner = "root";
      group = "root";
      mode = "0400";
    };

    security.acme = {
      acceptTerms = true;
      defaults = {
        dnsProvider = "cloudflare";
        credentialFiles."CF_DNS_API_TOKEN_FILE" =
          config.age.secrets.cloudflare-dns-api-token.path;
      };
    };
  };
}
