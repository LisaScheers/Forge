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

After deploying the configuration:

1. Sign in to https://gotify.bylisa.dev as the user who should receive the alerts.
   Enable **Authentik Plugin** under Plugins. Optionally set `friendly_name` to
   `auth.bylisa.dev`.
2. Copy the webhook URL shown by the plugin. Treat it as a secret: it contains
   the token for that user's plugin instance.
3. In Authentik, create a notification transport with mode **Webhook (generic)**,
   that URL, no webhook mapping, and **Send once** enabled.
4. Create a notification rule for the **authentik Admins** group, select that
   transport and severity **Notice**.
5. Bind three event matcher policies: **Login**, **Login Failed**, and **Logout**.
   Set the rule's policy engine mode to **Any** so any one of the events matches.

Plugin enablement and the generated webhook token are per-user Gotify database
state. The Nix configuration installs the plugin; the steps above activate
delivery. No production state is changed by the build check.

Upstream: https://github.com/ckocyigit/gotify-authentik-plugin
