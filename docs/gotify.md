# Gotify and Authentik

## Single sign-on

Gotify uses native OIDC with Authentik. Atlas applies the Gotify provider and
application blueprint; Nook reads the same client secret from
`secrets/shared/gotify-oidc-env.age`. Only Lisa, Atlas, and Nook can decrypt it.

Deploy Atlas before Nook so the OIDC discovery endpoint exists when Gotify starts.
Then choose **Login with Authentik** in Gotify. Browser and Android callback URLs
are registered. Existing Authentik sessions can be reused.

Access is limited to `authentik Admins`, whose members receive Gotify admin
permissions. First login creates a Gotify account. Local password login remains
available, and automatic linking to existing accounts is disabled. If a matching
local username already exists, SSO is rejected; confirm account ownership before
enabling `GOTIFY_OIDC_LINK_BY_USERNAME`. A new SSO account has its own applications,
tokens, messages, and plugin settings.

Configuration reference: https://integrations.goauthentik.io/monitoring/gotify/

## Event notifications

Nook builds the pinned Authentik plugin alongside Gotify, using Gotify's Go
toolchain and vendored dependencies. The build runs the plugin's tests and starts
an isolated Gotify instance to check that the plugin loads successfully.

The Atlas blueprint configures a generic webhook transport and a Notice rule for
`authentik Admins`, with event matchers for login, login failure, and logout.
Authentik evaluates notification matchers with Any semantics. `send_once` avoids
duplicate webhook deliveries when the group has several members.

The destination is Lisa's enabled Gotify plugin instance. Its secret URL is stored
as `GOTIFY_WEBHOOK_URL` in `secrets/atlas/gotify-webhook-env.age`, readable only by
Lisa and Atlas. No custom payload mapping is needed.

Plugin enablement and its token remain per-user Gotify database state. If the
plugin instance is recreated or its token changes, update the encrypted URL and
redeploy Atlas. On first deployment, start `authentik-gotify-blueprint.service`
explicitly if Authentik was already running; subsequent boots apply it before
Authentik starts. The isolated build check does not change production state.

Upstream: https://github.com/ckocyigit/gotify-authentik-plugin
