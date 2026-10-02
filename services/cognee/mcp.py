"""Attach Authentik OAuth to the upstream Cognee MCP server in API mode.

The MCP clients share Lisa's memory account. Authentik restricts that account
to its Admins group; this is not a per-Authentik-user Cognee tenancy mapping.
"""

import asyncio
import os

from fastmcp.server.auth.oidc_proxy import OIDCProxy
from src import server


server.mcp.auth = OIDCProxy(
    config_url="https://auth.bylisa.dev/application/o/cognee/.well-known/openid-configuration",
    client_id="cognee",
    client_secret=os.environ["COGNEE_OIDC_CLIENT_SECRET"],
    audience="cognee",
    forward_resource=False,
    base_url="https://cognee.local.bylisa.dev",
    jwt_signing_key=os.environ["COGNEE_MCP_JWT_SECRET"].encode(),
    required_scopes=["openid", "email", "profile", "offline_access"],
    allowed_client_redirect_uris=["http://127.0.0.1:*/callback*", "http://localhost:*/callback*"],
    require_authorization_consent=True,
    # Codex chats can retain different copies of a rotating refresh token.
    # Let the proxy renew Authentik tokens under its shared lock, while it
    # still validates the upstream token on every request.
    fastmcp_access_token_expiry_seconds=24 * 60 * 60,
    token_expiry_threshold_seconds=60,
)

# Upstream derives only http:// origins from MCP_ALLOWED_HOSTS. The actual
# endpoint is behind TLS, including the OAuth consent form's browser POST.
original_transport_security = server._transport_security_kwargs


def transport_security(host):
    settings = original_transport_security(host)
    settings.setdefault("allowed_origins", []).append("https://cognee.local.bylisa.dev")
    return settings


server._transport_security_kwargs = transport_security

if __name__ == "__main__":
    asyncio.run(server.main())
