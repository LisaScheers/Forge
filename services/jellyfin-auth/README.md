# Jellyfin authentication

Authentik LDAP through the official Jellyfin LDAP-Auth plugin v24 (Jellyfin 12).
Username/password login works in the web UI and native clients. This does not
add a browser SSO button. With the existing Authentik authentication flow, users
with TOTP may need `password;123456` for LDAP authentication.

Explicit existing-account links: `lisa`, `rose`. IDs are pinned in `link.py`.
`jade` and `esmee` have no Authentik account as of 2026-10-09; retain local login.
User creation and LDAP administrator synchronization are disabled. Library
permissions, administrator flags, passwords, user IDs, and watch history remain
in Jellyfin. This integration changes only the selected authentication provider.

The Atlas blueprint creates a dedicated LDAP provider, search service account,
application password, and access group. It adds the provider to the existing
UniFi LDAP outpost without replacing its other providers. TLS verifies the
existing `auth.bylisa.dev` certificate. Bind credentials are encrypted with
agenix and delivered to Jellyfin using systemd credentials.

The Nook linking service reads one existing administrator API key from the local
Jellyfin database, read-only. It keeps the key out of arguments and logs and uses
it only against loopback. An existing API key is required; Radarr, Sonarr and
Seerr currently supply these. It validates both pinned account IDs and LDAP
identities before changing any user policy through Jellyfin's supported API.
LDAP UID links are recorded by the plugin on successful user authentication.

Rollout requires Lisa's deployment approval: Atlas first, confirm the blueprint
and outpost provider, then Nook. Check `authentik-jellyfin-blueprint.service` on
Atlas and `jellyfin-auth-link.service` on Nook. Verify real sign-in for both linked
users and an existing native client. Their old local passwords no longer select
the default authentication provider.

To undo a link, stop/disable `jellyfin-auth-link.service` first and set the user's
authentication provider back to `Jellyfin.Server.Implementations.Users.DefaultAuthenticationProvider`
through Jellyfin's user settings/API. Existing local passwords are preserved.
Rolling back Nix alone does not reverse saved account policy changes.

Validation:

```sh
nix shell nixpkgs#python3 -c python3 -B -m unittest discover -s tests -p test_jellyfin_auth.py
```

Sources: [Authentik integration](https://integrations.goauthentik.io/media/jellyfin/),
[official plugin v24](https://github.com/jellyfin/jellyfin-plugin-ldapauth/releases/tag/v24).
