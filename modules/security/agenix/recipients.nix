{
  config,
  lib,
  ...
}: let
  keys = config.secrets.pubkeys;
  # Each secret is readable by Lisa and exactly the hosts that decrypt it;
  # rules-check.nix enforces the host part.
  atlas = [
    keys.users.lisa
    keys.hosts.atlas
  ];
  nook = [
    keys.users.lisa
    keys.hosts.nook
  ];
  vega = [
    keys.users.lisa
    keys.hosts.vega
  ];
  atlasAndNook = [
    keys.users.lisa
    keys.hosts.atlas
    keys.hosts.nook
  ];
in {
  # Features add rules beside their secrets; _secrets.nix reads the merged set.
  options.flake.agenixRules = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options.publicKeys = lib.mkOption {type = lib.types.listOf lib.types.str;};
    });
    default = {};
    description = "agenix recipients for each secret file, keyed by path relative to modules/security/agenix.";
  };
  config.flake.agenixRules = {
    "secrets/atlas/authentik-env.age".publicKeys = atlas;
    "secrets/atlas/gotify-webhook-env.age".publicKeys = atlas;
    "secrets/atlas/authentik-ldap-outpost-env.age".publicKeys = atlas;
    "secrets/atlas/auto-sync-update-env.age".publicKeys = atlas;
    "secrets/atlas/bluesky-pds-env.age".publicKeys = atlas;
    "secrets/atlas/cf-api-token.age".publicKeys = atlas;
    "secrets/atlas/forgejo-mailer-password.age".publicKeys = atlas;
    "secrets/atlas/forgejo-oidc-env.age".publicKeys = atlas;
    "secrets/atlas/jellyfin-bootstrap-env.age".publicKeys = atlas;
    "secrets/atlas/matrix-registration-secret.age".publicKeys = atlas;
    "secrets/atlas/matrix-turn-secret.age".publicKeys = atlas;
    "secrets/atlas/discord-bridge-env.age".publicKeys = atlas;
    "secrets/atlas/uptime-kuma-probes.age".publicKeys = atlas;

    "secrets/nook/cloudflare-dns-api-token.age".publicKeys = nook;
    "secrets/nook/cognee-backend-env.age".publicKeys = nook;
    "secrets/nook/gotify-env.age".publicKeys = nook;
    "secrets/nook/uptime-kuma-probes.age".publicKeys = nook;

    "secrets/vega/home-server-builder-ssh-key.age".publicKeys = vega;
    "secrets/vega/nix-github-access-token-conf.age".publicKeys = vega;

    "secrets/shared/cognee-oidc-env.age".publicKeys = atlasAndNook;
    "secrets/shared/gotify-oidc-env.age".publicKeys = atlasAndNook;
    "secrets/shared/jellyfin-ldap-env.age".publicKeys = atlasAndNook;
    "secrets/atlas/postplan-env.age".publicKeys = atlas;
  };
}
