{
  config,
  lib,
  ...
}: let
  keys = config.secrets.pubkeys;
  # Lisa plus exactly the hosts that decrypt the file. rules-check.nix checks
  # these rules against the hosts' configurations and the files' headers.
  readers = hosts: [keys.users.lisa] ++ map (host: keys.hosts.${host}) hosts;
in {
  # Every rule lives here; _secrets.nix gives agenix the same set.
  options.flake.agenixRules = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options.publicKeys = lib.mkOption {type = lib.types.listOf lib.types.str;};
    });
    default = {};
    description = "agenix recipients for each secret file, keyed by path relative to modules/security/agenix.";
  };
  config.flake.agenixRules = {
    "secrets/atlas/authentik-env.age".publicKeys = readers ["atlas"];
    "secrets/atlas/gotify-webhook-env.age".publicKeys = readers ["atlas"];
    "secrets/atlas/authentik-ldap-outpost-env.age".publicKeys = readers ["atlas"];
    "secrets/atlas/auto-sync-update-env.age".publicKeys = readers ["atlas"];
    "secrets/atlas/bluesky-pds-env.age".publicKeys = readers ["atlas"];
    "secrets/atlas/cf-api-token.age".publicKeys = readers ["atlas"];
    "secrets/atlas/forgejo-mailer-password.age".publicKeys = readers ["atlas"];
    "secrets/atlas/forgejo-oidc-env.age".publicKeys = readers ["atlas"];
    "secrets/atlas/jellyfin-bootstrap-env.age".publicKeys = readers ["atlas"];
    "secrets/atlas/matrix-registration-secret.age".publicKeys = readers ["atlas"];
    "secrets/atlas/matrix-turn-secret.age".publicKeys = readers ["atlas"];
    "secrets/atlas/postplan-env.age".publicKeys = readers ["atlas"];
    "secrets/atlas/discord-bridge-env.age".publicKeys = readers ["atlas"];
    "secrets/atlas/uptime-kuma-probes.age".publicKeys = readers ["atlas"];

    "secrets/nook/ai-proxy-antigravity-auth.age".publicKeys = readers ["nook"];
    "secrets/nook/ai-proxy-codex-auth.age".publicKeys = readers ["nook"];
    "secrets/nook/ai-proxy-openrouter-key.age".publicKeys = readers ["nook"];
    "secrets/nook/cloudflare-dns-api-token.age".publicKeys = readers ["nook"];
    "secrets/nook/cognee-backend-env.age".publicKeys = readers ["nook"];
    "secrets/nook/gotify-env.age".publicKeys = readers ["nook"];
    "secrets/nook/movie-night-env.age".publicKeys = readers ["nook"];
    "secrets/nook/uptime-kuma-probes.age".publicKeys = readers ["nook"];

    "secrets/vega/home-server-builder-ssh-key.age".publicKeys = readers ["vega"];
    "secrets/vega/nix-github-access-token-conf.age".publicKeys = readers ["vega"];

    "secrets/shared/ai-proxy-client-key.age".publicKeys = readers ["atlas" "nook" "vega"];
    "secrets/shared/cognee-oidc-env.age".publicKeys = readers ["atlas" "nook"];
    "secrets/shared/gotify-oidc-env.age".publicKeys = readers ["atlas" "nook"];
    "secrets/shared/jellyfin-ldap-env.age".publicKeys = readers ["atlas" "nook"];
  };
}
