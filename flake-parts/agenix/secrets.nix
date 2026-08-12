let
  keys = import ./pubkeys.nix;
  all = [
    keys.users.lisa
    keys.hosts.atlas
    keys.hosts.nook
    keys.hosts.vega
  ];
  nook = [
    keys.users.lisa
    keys.hosts.nook
  ];
  vega = [
    keys.users.lisa
    keys.hosts.vega
  ];
  postplan = [
    keys.users.lisa
    keys.hosts.atlas
  ];
  ponyTack = [
    keys.users.lisa
    keys.hosts.atlas
  ];
in {
  "secrets/atlas/authentik-env.age".publicKeys = all;
  "secrets/atlas/authentik-ldap-outpost-env.age".publicKeys = all;
  "secrets/atlas/auto-sync-update-env.age".publicKeys = all;
  "secrets/atlas/bluesky-pds-env.age".publicKeys = all;
  "secrets/atlas/cf-api-token.age".publicKeys = all;
  "secrets/atlas/forgejo-runner-token.age".publicKeys = all;
  "secrets/atlas/matrix-registration-secret.age".publicKeys = all;
  "secrets/atlas/matrix-turn-secret.age".publicKeys = all;
  "secrets/atlas/monitoring-otlp-env.age".publicKeys = all;
  "secrets/atlas/pony-tack-deploy-key.age".publicKeys = ponyTack;
  "secrets/atlas/pony-tack-env.age".publicKeys = ponyTack;
  "secrets/atlas/shop-empty-track-env.age".publicKeys = all;
  "secrets/atlas/sl-remote-credentials.age".publicKeys = all;

  "secrets/nook/cloudflare-dns-api-token.age".publicKeys = nook;
  "secrets/nook/gotify-env.age".publicKeys = all;
  "secrets/nook/grafana-authentik-client-secret.age".publicKeys = nook;
  "secrets/nook/monitoring-otlp-htpasswd.age".publicKeys = nook;
  "secrets/nook/onepassword-connect-credentials.age".publicKeys = nook;
  "secrets/nook/vaultwarden-admin-token-env.age".publicKeys = all;
  "secrets/nook/vaultwarden-env.age".publicKeys = all;
  "secrets/nook/vaultwarden-restic-env.age".publicKeys = all;
  "secrets/nook/vaultwarden-restic-ssh-key.age".publicKeys = all;

  "secrets/vega/home-server-builder-ssh-key.age".publicKeys = all;
  "secrets/vega/nix-github-access-token-conf.age".publicKeys = vega;

  "secrets/shared/github-env.age".publicKeys = all;
  "secrets/shared/postplan-env.age".publicKeys = postplan;
}
