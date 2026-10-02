# Cognee on Nook

Status: configuration prepared; not deployed or signed in. A successful Luna
inference and a remember/recall round trip are still required before this can be
called operational. No OpenAI API billing fallback is enabled.

## Storage and services

Read-only inspection on 2026-10-02 found about 304 GiB free on Nook's projects
NVMe, 208 GiB on the Kingston SSD, and only 19 GiB on the system SSD. The Kingston
disk already has a 190,000 MB Squid cache budget. All new persistent state goes
under `/srv/disks/projects/cognee`:

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

Nginx allows the existing home LAN ranges and Tailscale ranges, requires TLS, and
disables access logs. Nook's Unbound publishes the name locally. An off-LAN client
also needs a route and DNS resolution to Nook (for example tailnet split DNS for
`local.bylisa.dev` through Nook); the configuration does not change tailnet DNS.

No separate UI container, PostgreSQL, Neo4j, Redis, or vector service is needed.
Extraction gets at most two CPUs and 6 GiB; MCP gets two CPUs and 2 GiB. The
adapter is limited to 256 MiB. Nook had about 14 GiB available at inspection.

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
usage/credit allowance remain Lisa's choices. No credits or API spending have been
authorized by preparing this configuration.

Authorize on Vega, where the browser and loopback callback are on the same machine:

```sh
nix run .#cognee-openai-login
```

Open the printed **Continue with ChatGPT** URL and approve the dedicated Forge
Cognee registration. The result is saved at
`~/.local/state/forge-cognee/nook-openai.json`, without printing tokens. Re-running
reauthorizes the same registration and rejects a different account identity.

After the approved Nook deployment creates its directories, securely transfer
that credential record:

```sh
scp ~/.local/state/forge-cognee/nook-openai.json nook:/home/lisa/cognee-openai.json
ssh nook 'sudo install -o root -g root -m 0600 /home/lisa/cognee-openai.json /srv/disks/projects/cognee/openai/credentials.json && rm /home/lisa/cognee-openai.json'
```

Nook owns subsequent refreshes. Do not run a second adapter or another refresh
process using the same copied registration. Stop using the local copy after
transfer. To revoke access, disconnect Forge Cognee in ChatGPT Settings; stop the
adapter before removing its runtime credentials. Missing credentials produce a
503 and do not trigger a billed API fallback.

## Authentication and permissions

The Atlas blueprint creates a confidential Authentik `cognee` provider, binds its
application to `authentik Admins`, and configures the strict callback
`https://cognee.local.bylisa.dev/auth/callback`. OpenID/email/profile/offline-access
scopes enable login and refresh. FastMCP's OIDC proxy provides MCP client
registration and consent, verifies Authentik tokens for the Cognee audience, and
persists encrypted client state under `mcp`. Its signing key is stable across
restarts. A normal nginx browser-login redirect is not sufficient MCP OAuth.

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

Encrypted backend secrets are limited to Lisa and Nook. The Authentik OIDC secret
and MCP signing key are limited to Lisa, Nook and Atlas. No plaintext secret is
placed in Nix settings or the repository.

## Codex setup

Home Manager declares the remote MCP entry for Lisa. Its activation updates only
that entry in the mutable `~/.codex/config.toml`, preserving the model and other
MCP settings. Nook's `codex` daemon also receives the same entry. MCP operations
have a 600-second timeout; deleting memory through `forget` requires confirmation.

After deployment, update the current Vega config through the existing approved
Home Manager/nix-darwin activation, or apply only the managed entry without a
daily-driver rebuild:

```sh
codex mcp add cognee --url https://cognee.local.bylisa.dev/mcp
codex mcp login cognee
```

The declarative activation also installs the longer timeout and `forget` policy.
For the dedicated Nook daemon account, log in to MCP as that account so it owns
its credentials; use an SSH loopback tunnel if performing the browser login from
Vega. Restart the daemon only after its login is saved. Authentication and tool
discovery must be verified separately from the settings entry.

MCP lists its four tools directly: `remember`, `recall`, `forget` and
`cognify_status`. The `all` mode removes the generic `call_tool` proxy, ensuring
deletion reaches Codex through the configured `forget` confirmation policy.

The optional Cognee memory plugin captures prompts, traces and responses
automatically. It is not enabled here: the requested MCP connection provides
explicit remember/recall tools without copying every session. Personal facts
remain recorded in the Life repository as specified by Lisa's instructions.

## Rollout and verification

Source evaluation and adapter tests are local preparation, not deployment. Follow
Forge's deployment instructions: get the reviewed revision onto `origin/main`
before an approved manual rollout. Deploy Atlas's Authentik application first,
then Nook. Avoid activation from an off-main revision.

Preparation checks passed on 2026-10-02: Nook and Atlas system derivation
evaluation, Vega Home Manager evaluation, the packaged login helper's build and
help command, and 18 adapter tests. An offline compatibility check against
FastMCP 3.4.7 verified anonymous MCP rejection, HTTPS OAuth discovery and
Host/Origin rejection with mocked Authentik discovery. The pinned containers,
live Authentik login and Cognee memory round trip remain untested until rollout.

```sh
just deploy-build atlas
just deploy atlas
just deploy-build nook
just deploy nook
```

After authorization and credential transfer, verify:

1. Data directories and Podman's graphroot are on the NVMe, not the system SSD.
2. `podman-cognee`, `cognee-bootstrap`, `podman-cognee-mcp` and
   `cognee-openai-plan` are healthy. The API logs authentication enabled.
3. Anonymous REST calls return 401; anonymous MCP initialization returns an OAuth
   challenge. An Authentik account outside the allowed group cannot authorize.
4. A Luna structured extraction completes. The account catalog is not definitive. Check
   ChatGPT Settings → Usage for the app's plan allowance.
5. In a disposable dataset, remember a short fact and recall it in a fresh Codex
   chat. Check pipeline completion, then restart the services and repeat recall to
   confirm persistence. Delete only that test dataset after confirmation.
6. Confirm denied file-path and outbound URL ingestion, with valid uploaded text
   still accepted.

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
