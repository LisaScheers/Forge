# Cognee on Nook

Status: deployed and verified on 2026-10-02. GPT-6 Luna completed structured
extraction using Lisa's ChatGPT subscription. Lisa's Vega Codex and Nook's `codex`
account are signed in through Authentik; a fresh Codex chat recalled a synthetic
fact after the API and MCP restarted. No OpenAI API billing fallback is enabled.

## Storage and services

Initial inspection on 2026-10-02 found about 304 GiB free on Nook's projects
NVMe, 208 GiB on the Kingston SSD, and only 19 GiB on the system SSD. The Kingston
disk already has a 190,000 MB Squid cache budget. All new persistent state goes
under `/srv/disks/projects/cognee`; about 298 GiB remained after deployment:

| Directory | Contents |
| --- | --- |
| `system` | SQLite metadata, per-user/dataset LanceDB vectors and Kuzu/Ladybug graph files |
| `data` | Uploaded source documents |
| `cache` | Local embedding weights, tokenizers and logs |
| `containers` | Podman images and writable layers |
| `mcp` | Encrypted FastMCP OAuth client registrations and upstream tokens |
| `credentials` | The MCP service's Cognee API key, private to root |
| `openai` | Dedicated ChatGPT plan registration and rotating tokens, private to root |

Cognee runs as uid/gid 970; the existing Nook account and group databases were
checked for conflicts. Services require the actual data mount, preventing writes
to the system filesystem when the SSD is unavailable. Container images are pinned
to the observed amd64 registry digests, rather than following `main` silently.

The REST API owns the embedded databases. MCP uses API mode and does not mount
those database directories. This avoids competing embedded graph writers.
Both containers share the host network but bind only to loopback:

| Listener | Purpose |
| --- | --- |
| `127.0.0.1:8320` | ChatGPT plan adapter, authenticated with a private local key |
| `127.0.0.1:8321` | Cognee REST API |
| `127.0.0.1:8322` | Cognee MCP with Authentik OAuth |
| `https://cognee.local.bylisa.dev/mcp` | Codex MCP endpoint |
| `https://cognee.local.bylisa.dev/api/v1/…` | REST endpoint for other AI workloads |
| `https://cognee.local.bylisa.dev/graph/` | Authentik-protected, read-only graph viewer |

Nginx allows the existing home LAN ranges and Tailscale ranges, requires TLS, and
disables access logs. Nook's Unbound publishes the name locally. An off-LAN client
also needs a route and DNS resolution to Nook (for example tailnet split DNS for
`local.bylisa.dev` through Nook); the configuration does not change tailnet DNS.

No separate UI container, PostgreSQL, Neo4j, Redis, or vector service is needed.
Extraction gets at most two CPUs and 6 GiB; MCP gets two CPUs and 2 GiB. The
adapter is limited to 256 MiB. Nook had about 14 GiB available at inspection.

## Graph viewer

Open `https://cognee.local.bylisa.dev/graph/` and sign in through Authentik.
The same `authentik Admins` group allowed to use MCP can open the viewer. It
defaults to the ingested `life` dataset and uses Cognee's own renderer, including
Story, Flow and Force layouts, node search, node/edge details, zoom and the
schema/memory tabs. Dark mode is the default; the native toggle saves your choice.

The default view is a bounded 500-node neighborhood. Use `?max_nodes=2000` or `?max_nodes=5000`
for a larger neighborhood, or `?full=true` for the whole dataset (which can be
slow for large datasets). Select another readable dataset with `?dataset_id=UUID`.
Reload the page to fetch newly ingested memory. These controls affect graph
display; they do not run inference or change stored memory.

`cognee-graph` serves a private Unix socket through nginx's Authentik forward
auth, with a separate declarative proxy provider on Atlas. It requests only
Cognee's visualization GET using the existing ordinary account's server-side key;
it does not expose a general API proxy or send that key to the browser. Browser
requests cannot upload or delete memory. The API and MCP keep their existing
authentication. D3 is hash-pinned and served locally; external fonts are removed,
and the page's CSP restricts assets and connections to this origin. Responses
are not cached and graph request URLs are not logged. This viewer adds no new
persistent data store or frontend container.

## Models and subscription access

Extraction and reasoning use `gpt-6-luna`, with low reasoning effort and a 16,384
output-token budget. Local Fastembed runs `sentence-transformers/all-MiniLM-L6-v2`
with 384 dimensions. Its weights and tokenizer cache persist on the NVMe; first
use requires a model download. Input chunk sizing is capped at 256 embedding
tokens. Cognee's LLM rate limiter is set to ten requests per minute.

Cognee does not document a native ChatGPT plan provider. Its MCP sampling option
requires support from the client and does not cover embeddings. Connecting Codex
to Cognee alone does not make Cognee's background extraction use Codex's plan.

`services/cognee/openai_plan.py` translates Cognee's text Chat Completions calls
to OpenAI's documented subscription flow at `https://api.openai.com/v1/responses`.
It preserves structured-output schemas, uses `store=false` and `stream=true`, and
collects finalized output items but releases them only after `response.completed`.
The subscription endpoint rejects `max_output_tokens`; the adapter rejects a
completed response exceeding Cognee's budget, but cannot cap provider consumption.
Partial streams, refusals,
incomplete responses and plan-limit failures fail rather than ingesting partial
results. It supports text extraction/reasoning only; audio transcription and
image captioning require an additional provider before those workloads are used.

The adapter uses its own registration, not `~/.codex/auth.json`. The stable Nook
host ID is `urn:uuid:128b7566-1f4a-4f61-9df0-94a3d04f2389`. Sign-in validates state,
PKCE, the ID-token signature, issuer, audience, expiry, nonce and account identity.
Scope `chatgpt.tokens.use.direct` must be granted. Credentials are written
atomically with mode 0600. One adapter process serializes rotating refreshes.

**Availability remains account-dependent.** A completed inference is the
entitlement check. On 2026-10-02 the account catalog omitted GPT-6 Luna, but the
model completed a real subscription request successfully. The adapter's `/models`
route therefore reports its configured model rather than filtering by that catalog. Subscription
usage shares the account's applicable limits. Login consent and any app-specific
usage allowance remain Lisa's choices. The deployed service uses the authorized
subscription connection; it has no API billing credentials.

Authorize on Vega, where the browser and loopback callback are on the same machine:

```sh
nix run .#cognee-openai-login
```

Open the printed **Continue with ChatGPT** URL and approve the dedicated Forge
Cognee registration. The result is saved at
`~/.local/state/forge-cognee/nook-openai.json`, without printing tokens. Re-running
reauthorizes the same registration and rejects a different account identity.

For reauthorization, stop the adapter before replacing credentials. Securely
transfer the new record over SSH stdin, without a plaintext staging file on Nook:

```sh
ssh nook 'sudo systemctl stop cognee-openai-plan'
ssh nook "sudo sh -c 'umask 077; cat > /srv/disks/projects/cognee/openai/credentials.json'" \
  < ~/.local/state/forge-cognee/nook-openai.json
ssh nook 'sudo systemctl start cognee-openai-plan'
```

Nook owns subsequent refreshes. Do not run a second adapter or another refresh
process using the same copied registration. Stop using the local copy after
transfer. The initial rollout verified the transferred file hash and removed
access, refresh and ID tokens from the local record, retaining only registration
metadata for future authorization. To revoke access, disconnect Forge Cognee in ChatGPT Settings; stop the
adapter before removing its runtime credentials. Missing credentials produce a
503 and do not trigger a billed API fallback.

## Authentication and permissions

The Atlas blueprint creates a confidential Authentik `cognee` provider, binds its
application to `authentik Admins`, and configures the strict callback
`https://cognee.local.bylisa.dev/auth/callback`. OpenID/email/profile/offline-access
scopes enable login and refresh. FastMCP's OIDC proxy provides MCP client
registration and consent, verifies Authentik tokens for the Cognee audience, and
persists encrypted client state under `mcp`. Its signing key is stable across
restarts. MCP uses warning-level logging to avoid storing OAuth callback codes
in the journal. A normal nginx browser-login redirect is not sufficient MCP OAuth.

**The MCP endpoint is one shared personal memory account.** Authentik controls who
can reach that account; it does not map each Authentik user to a separate Cognee
user. Keep application membership limited to trusted administrators. For other
workloads, create separate Cognee accounts and API keys over SSH, then grant only
the dataset permissions that need sharing. Dataset-name filters alone are not
access controls.

Cognee has `REQUIRE_AUTHENTICATION=true`, `ENABLE_BACKEND_ACCESS_CONTROL=true` and
`HASH_API_KEY=true` from the first startup. JWT, verification and reset secrets
persist through agenix. The bootstrap registers an ordinary MCP account, mints
one API key and reuses it across restarts. A revoked persisted key fails bootstrap
instead of being silently replaced. The default superuser has no configured
password; public user enrollment is blocked at Nginx.

Server-local file ingestion and outbound URL ingestion are disabled. Upload
documents from the client rather than passing Nook paths or asking the server to
fetch arbitrary URLs. The data volume and image filesystem are the only mounts
visible to the API; OpenAI credentials are not mounted into it. The model's
first-use download and normal LLM traffic remain allowed.

The pinned API has an ingestion bug: disabling client-supplied file paths also
blocks its internal loader from reading uploaded files. `services/cognee/api.py`
enables paths only in that internal loader. The initial input boundary remains
disabled, and both path rejection and successful text upload were verified live.

Encrypted backend secrets are limited to Lisa and Nook. The Authentik OIDC secret
and MCP signing key are limited to Lisa, Nook and Atlas. No plaintext secret is
placed in Nix settings or the repository.

## Codex setup

Home Manager declares the remote MCP entry for Lisa. Its activation updates only
that entry in the mutable `~/.codex/config.toml`, preserving the model and other
MCP settings. Nook's `codex` daemon also receives the same entry. MCP operations
have a 600-second timeout; deleting memory through `forget` requires confirmation.

The managed Vega entry was applied without rebuilding the daily driver, preserving
Lisa's selected Codex model. Both account logins and live tool discovery passed.
New Codex chats load this connection. For subsequent sign-in on Vega:

```sh
codex mcp login cognee --no-browser
```

Open the printed URL in Helium, grant Cognee access and complete Authentik sign-in.
For Nook's daemon account, use the headless flow as that account:

```sh
ssh -tt nook 'sudo -iu codex /etc/profiles/per-user/codex/bin/codex -c '\''mcp_servers.cognee.url="https://cognee.local.bylisa.dev/mcp"'\'' mcp login cognee --no-browser'
```

Open its URL in Helium. After approval, the browser may show an unreachable
localhost callback because that callback belongs to Nook. Paste the complete
callback URL into the waiting SSH prompt and press Enter. Never publish or log
that URL. Restart `codex.service` after the login is saved. Nook stores these
credentials in `/home/codex/.codex/.credentials.json`, owned by `codex`, mode 0600.

Ask Codex to remember or recall selected information, specifying a dataset when
separating workloads. For example: "Remember in dataset project_notes: the release
checklist lives in docs/release.md." Then use a new chat to ask it to recall that
checklist location from the same dataset.

MCP lists its four tools directly: `remember`, `recall`, `forget` and
`cognify_status`. The `all` mode removes the generic `call_tool` proxy, ensuring
deletion reaches Codex through the configured `forget` confirmation policy.

The optional Cognee memory plugin captures prompts, traces and responses
automatically. It is not enabled here: the requested MCP connection provides
explicit remember/recall tools without copying every session. Personal facts
remain recorded in the Life repository as specified by Lisa's instructions.

## Rollout and verification

Changes were published to `origin/main` before the approved manual rollout.
Atlas's Authentik application was deployed first, then Nook. Subsequent updates
must follow the same Forge deployment path:

```sh
just deploy-build atlas
just deploy atlas
just deploy-build nook
just deploy nook
```

Verified on 2026-10-02:

- Nook/Atlas system and Vega Home Manager evaluations; packaged login helper;
  18 adapter tests and FastMCP 3.4.7 OAuth/HTTPS origin compatibility checks.
- Persistent data, model cache and Podman storage reside on the projects NVMe.
  All three application listeners bind only to `127.0.0.1`.
- Trusted Let's Encrypt TLS; public health returns 200; anonymous REST and MCP
  return 401; MCP advertises OAuth discovery; public registration returns 403.
- Authentik provider and administrator-group binding are present. Lisa completed
  browser authorization; both Vega and Nook Codex accounts discover all four tools.
  A separate non-administrator login was not exercised.
- GPT-6 Luna structured inference and Cognee graph extraction completed through
  the subscription adapter. Synthetic text ingestion completed in about 18 seconds.
- REST graph recall returned the synthetic fact. After API/MCP restart, a fresh
  Codex chat recalled the same fact through its authenticated MCP connection.
- Authenticated server-path ingestion returns 415; outbound URL ingestion returns
  403; uploaded text succeeds. The disposable verification dataset was removed.

The API and MCP have bounded startup HTTP readiness gates (240 seconds). Podman's
automatic health timers are disabled because their early transient failures
triggered deploy-rs rollback during normal startup. Manual health checks remain:

```sh
ssh nook 'sudo podman healthcheck run cognee && sudo podman healthcheck run cognee-mcp'
```

`cognee-bootstrap` is a successful oneshot, so an inactive state after completion
is normal. `cognee-openai-plan`, `podman-cognee`, `podman-cognee-mcp` and `codex`
should be active. Check ChatGPT Settings → Usage for the app's subscription limits.

Never expose the loopback ports directly. There is no remote off-machine backup
destination configured for Cognee yet. Before an image upgrade, stop MCP and API,
take a consistent backup of `system`, `data`, `credentials`, `openai` and `mcp`, and
retain the agenix secrets. Cached models and images can be re-created. Treat the
backup as sensitive: graph data, source documents and renewable tokens are in it.

## Documentation review

The full-site export fetched on 2026-10-02 is 4,401,351 bytes / 67,838 lines,
including duplicate Cloud/API surfaces. Relevant deployment/configuration,
database isolation, security, provider, MCP and Codex chapters were inspected,
with behavior checked against upstream source commit
`b32d8afc59e1064d9291b9828a8a147be9cc8bab`. Some documentation and source differ:
Fastembed is already a core dependency in that source; some docs still describe
it as an optional extra. The upstream MCP image's HTTP-only origin derivation is
extended by the wrapper to accept the actual HTTPS origin.

Primary references:

- [Cognee full documentation export](https://docs.cognee.ai/llms-full.txt)
- [Configuration overview](https://docs.cognee.ai/setup-configuration/overview)
- [Security and privacy](https://docs.cognee.ai/setup-configuration/security)
- [Permissions](https://docs.cognee.ai/setup-configuration/permissions)
- [LLM providers](https://docs.cognee.ai/setup-configuration/llm-providers)
- [Embedding providers](https://docs.cognee.ai/setup-configuration/embedding-providers)
- [Relational databases](https://docs.cognee.ai/setup-configuration/relational-databases)
- [Graph stores](https://docs.cognee.ai/setup-configuration/graph-stores)
- [Vector stores](https://docs.cognee.ai/setup-configuration/vector-stores)
- [Docker deployment](https://docs.cognee.ai/how-to-guides/cognee-sdk/deployment/docker)
- [REST API deployment](https://docs.cognee.ai/guides/deploy-rest-api-server)
- [Cognee MCP setup](https://docs.cognee.ai/cognee-mcp/mcp-local-setup)
- [Codex MCP integration](https://docs.cognee.ai/cognee-mcp/integrations/codex)
- [Cognee Codex memory plugin](https://docs.cognee.ai/integrations/codex-integration)
- [FastMCP OIDC proxy](https://gofastmcp.com/servers/auth/oidc-proxy)
- [Authentik OAuth provider](https://docs.goauthentik.io/add-secure-apps/providers/oauth2/)
- [OpenAI ChatGPT plan usage](https://developers.openai.com/siwc/token-sharing-open-source)
- [OpenAI registration and sign-in](https://developers.openai.com/siwc/token-sharing-open-source/sign-in)
- [OpenAI models and inference](https://developers.openai.com/siwc/token-sharing-open-source/models-and-inference)
- [OpenAI self-hosted credentials](https://developers.openai.com/siwc/token-sharing-open-source/self-hosted-vms)
- [GPT-6 Luna](https://developers.openai.com/api/docs/models/gpt-6-luna)
- [Codex MCP configuration](https://learn.chatgpt.com/docs/extend/mcp?surface=cli)
