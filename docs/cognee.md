# Cognee on Nook

Status: GLM 5.3 Flash through OpenRouter was deployed and verified on 2026-10-03
after Lisa approved replacing GPT-6 Luna. JSON-schema inference and a full MCP
write, graph build and retrieval passed in the `forge_operations` dataset.
Existing `life` memory remains readable. Lisa subsequently chose local searchable
email indexing with a maximum $10 OpenRouter import budget. The paid bulk run was
stopped, and cleaned emails use a deterministic pipeline with local embeddings.
Lisa's Vega Codex and Nook's `codex` account use Authentik. OpenRouter usage is
billed to Lisa's existing OpenRouter account.
Graph storage was recovered and the viewer and MCP recall verified again on
2026-10-03; the deployed graph library and buffer limits are described below.

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
The API gets at most four CPUs and 6 GiB; MCP gets two CPUs and 2 GiB. The
retired ChatGPT adapter is no longer a running service. Nook had about 14 GiB
available at inspection.
The graph buffer pool is explicitly limited to 1 GiB: Cognee's 32 GiB default
exceeds the container's memory limit and caused a graph-worker OOM on 2026-10-02.
The API image's Ladybug 0.19.0 is overridden with hash-pinned 0.21.0 and its
matching JSON extension. This fixes the [large-record WAL checksum bug](https://github.com/LadybugDB/ladybug/pull/959).
Both artifacts are read-only Nix mounts; no runtime package installation is used.

## Graph storage recovery

On 2026-10-03 the viewer returned "Cognee could not render this graph" because
the graph could not replay its corrupted `.wal.checkpoint`. The graph worker had
also exceeded the 6 GiB container limit. All writers were stopped before copying
`system` and `data` into `/srv/disks/projects/cognee/recovery/20261003`, private to
root. The original database and checkpoint log remain in that snapshot.

Recovery was tested on a separate copy with Ladybug 0.21.0. Its native recovery
mode replayed valid committed records and discarded the unreadable tail, then a
strict reopen succeeded with 21,362 nodes and 52,029 relationships. All 59 source
items marked fully processed were represented by document nodes. All 99 uploaded
source files were present; the other 40 items had not completed graph processing
before recovery. This does not certify every edge of an interrupted transaction
or mark pending uploads as processed. SQLite, vectors, and source files were not
replaced with an older snapshot.

A separate 5 KiB string-record test reproduced WAL replay failure on 0.19.0 and
passed on 0.21.0 after abrupt process exit. The matching JSON extension also
loaded without network access.
The live viewer then rendered its default 500-node neighborhood (726 edges) in
Helium, and MCP `recall` returned a result from `life`. Anonymous REST and MCP
requests still returned 401. The API container remained below 3 GiB during that
render with no cgroup OOM events. Large graphs still incur vector reads and
semantic layout work; this is not an instant-render guarantee.

Keep the upgraded library and matching JSON extension together. Ladybug can
upgrade the database's storage format when opening it; a rollback to the image's
0.19 library alone is not a safe database rollback. Retain the original snapshot
and stop all writers before any further recovery or restore.

## Graph viewer

Deployed and verified in Helium on 2026-10-02, including Story/Flow/Force,
node search and the existing Authentik session. Anonymous requests redirect to
sign-in; the REST API and MCP still reject anonymous requests.

Open `https://cognee.local.bylisa.dev/graph/` and sign in through Authentik.
The same `authentik Admins` group allowed to use MCP can open the viewer. It
defaults to the ingested `life` dataset and uses Cognee's own renderer, including
Story, Flow and Force layouts, node search, node/edge details, zoom and the
schema/memory tabs. Dark mode is the default; the native toggle saves your choice.

The default view is a bounded 500-node neighborhood. Use `?max_nodes=2000` or `?max_nodes=5000`
for a larger neighborhood, or `?full=true` for the whole dataset (which can be
slow for large datasets). Select another readable dataset with `?dataset_id=UUID`.
Reload the page to fetch newly ingested memory. These controls affect graph
display; they do not call the LLM or change stored memory. The semantic
projection can use local embeddings. Graph/database and numeric-library threads
are limited to two to match the container CPU quota. The first 500-node view
loaded in about 29 seconds after a backend restart; larger views can take longer.

`cognee-graph` serves a private Unix socket through nginx's Authentik forward
auth, with a separate declarative proxy provider on Atlas. It requests only
Cognee's visualization GET using the existing ordinary account's server-side key;
it does not expose a general API proxy or send that key to the browser. Browser
requests cannot upload or delete memory. The API and MCP keep their existing
authentication. D3 is hash-pinned and served locally; external fonts are removed,
and the page's CSP restricts assets and connections to this origin. Responses
are not cached and graph request URLs are not logged. This viewer adds no new
persistent data store or frontend container.

## Models

Extraction and reasoning use `openrouter/z-ai/glm-5.3-flash` with
`LLM_PROVIDER=custom`, `LLM_ENDPOINT=https://openrouter.ai/api/v1` and a 16,384
output-token budget. The existing OpenRouter key is stored as `LLM_API_KEY` in
the encrypted `cognee-backend-env.age` secret, readable by Lisa and Nook. No key
is stored in Nix settings or plaintext staging files. OpenRouter usage consumes
Lisa's OpenRouter credits. The exact model slug and structured output were
verified with a real request before changing the secret.

Local Fastembed runs `sentence-transformers/all-MiniLM-L6-v2` with 384 dimensions.
Its weights and tokenizer cache persist on the NVMe; first use requires a model
download. Input chunk sizing is capped at 256 embedding tokens.
Fastembed's ONNX thread pools are explicitly limited to four, matching the
container quota. A 128-item benchmark on Nook took 22.86 seconds with automatic
host-sized pools against a two-CPU limit, 5.847 seconds with two threads/two CPUs,
and 4.336 seconds with four threads/four CPUs. Embedding batches are 128 rather
than the default 36, reducing small LanceDB writes. The thread setting prevents CPU-quota
throttling from idle spinning. `api.py` passes the declarative `FASTEMBED_THREADS`
setting through Cognee's Fastembed constructor.
`LLM_RATE_LIMIT_REQUESTS=10` sets the configured RPM budget. The image defaults
to automatic rate limiting after provider errors, rather than an always-enabled
proactive cap.

The earlier GPT-6 Luna subscription adapter and login helper remain in the
repository for reference, but the adapter service and its dependency were
removed. Its dedicated OAuth record remains private under `openai`; it is not
used for active inference. Switching to OpenRouter does not revoke that earlier
ChatGPT authorization. See [Cognee's OpenRouter configuration](https://docs.cognee.ai/setup-configuration/llm-providers)
and [GLM 5.3 Flash](https://openrouter.ai/z-ai/glm-5.3-flash).

## Local email import

Lisa selected a local searchable email index on 2026-10-03. Importing these
emails makes no OpenRouter calls. GLM remains available for ordinary memory
writes and question answering; those are separate from the local import.

`services/cognee/email_filter.py` reads the preserved Apple Mail exports and
produces private cleaned JSONL, exclusion records and a source-hash report on
Nook. The coverage check includes the personal export's optional original-date
header. The first full pass covered 32,930 records across 37 uploaded exports:
219 duplicates, 18,461 marketing/broadcast messages, 35 test messages, 186
expired authentication notices, nine unsubscribe requests and 12 empty notices
were excluded. 14,008 messages remain, with 31,431,664 bytes of cleaned bodies. The source
communications remain dated evidence; missing senders or dates stay unknown.
339 retained messages have no usable date in either export field. Raw date
fields remain in chunk metadata; MCP reports unknown dates and omits missing
header markers rather than presenting them as dates.
Invoices, useful attachment references, human replies and employee-benefit
newsletters are retained. Original source files are not deleted or edited.

The import completed on 2026-10-03: all 58 cleaned batches, 14,008 emails and
78,768 chunks. Full verification matched every expected chunk's text and
metadata and all uploaded batch hashes, with zero missing chunks. It removed
64 obsolete derived chunks only after their replacements passed verification.
The local pipeline recorded zero input/output LLM tokens, and OpenRouter usage
was unchanged before and after the import: $0 additional import charges.
The private verification report is in
`/srv/disks/projects/cognee/email-import/20261003-index-v3/verification.json`.

The report and exclusions live under
`/srv/disks/projects/cognee/email-import/20261003-filter-v3`, private to root.
`archive-source-ids.json` registers original corpus IDs, excluding those dumps
from later paid cognify runs without marking them as graph-processed. Their
already-completed graph material remains. Raw upload pending counts therefore
also include these intentionally archived inputs. Chunk searches exclude their
superseded raw-export payloads before ranking, so previously indexed marketing
does not compete with the cleaned archive. Source files and graph memory remain.

Labeled cleaned uploads (`forge-email-index-v1`) in `life` use
`services/cognee/email_index.py`: source/date-bearing document chunks and local
MiniLM embeddings in Cognee's native LanceDB collection. This indexes source text
rather than synthesizing personal facts. Per-chunk graph and provenance writes
were the main pilot bottleneck and are omitted for this searchable archive;
existing graph memory remains available. The
authenticated `POST /api/v1/email-index` endpoint requires write permission on
the dataset and accepts only IDs of labeled uploads in that dataset. It starts
the pipeline with LLM and embedding connection probes disabled; actual storage
uses the configured local Fastembed engine. Normal cognify retries also route
these labeled items through the local task list. Import completion and failures
appear under Cognee's `cognify_pipeline`; a queued request is not completion.

Use MCP `recall` with `datasets="life"` and `search_type="CHUNKS"` for semantic
email retrieval without an LLM call. `CHUNKS_LEXICAL` is useful for exact names
and identifiers; its BM25 corpus reads the dataset's native LanceDB chunk payloads.
The MCP formatter exposes dates and original source links on every email hit,
including later chunks. Oversized unbroken strings are split without dropping
characters before embedding. Results retain original message links or mbox ordinal references;
attachment contents were never included in the source export.

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

The OAuth proxy issues client access tokens for 24 hours and renews the underlying
Authentik token on the server, using FastMCP's shared refresh lock. This reduces
refresh-token rotation races between Codex chats; every request still validates
the upstream token. An already rejected refresh token requires a new login.
This is a mitigation for the client-side race, not a guarantee that every old
chat reconnects automatically. See the [FastMCP token lifetime guidance](https://gofastmcp.com/servers/auth/oauth-proxy).

On 2026-10-03 the affected Codex chat logged "OAuth authorization required" at
startup, and Nook repeatedly rejected an already-rotated refresh token. Vega's
Codex login was renewed in Helium after deploying the lifetime change. MCP reads
and writes passed afterward, and anonymous MCP requests still returned 401.
The global agent instructions now require fresh availability checks and
distinguish queued writes from completed graph ingestion.

`remember(background=true)` queues processing; it does not prove that a fact is
searchable yet. Check `cognify_status` and retrieve the fact before reporting a
completed graph write. In this release a permanent remember processes pending
items in the same dataset, including earlier uploads. A large or failed
email batch can therefore delay a small correction behind pending ingestion.

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
