# Shared AI gateway and token capture

One CLIProxyAPIPlus instance runs on Nook and archives its full request logs in
ClickHouse. Nook and Vega were deployed and verified on 2026-11-05, including
Vega's final system-generation switch. Asterion is excluded for now. Codex,
T3's Codex driver, Antigravity CLI, and Cognee have client routes in this change.

The API endpoint is `https://cliproxy.local.bylisa.dev`. Managed machines map it to
Nook's stable Tailscale address, `100.106.233.104`. Tailscale uses a direct LAN path
when available and keeps the same endpoint reachable remotely. LAN DNS also
resolves the name to Nook's LAN address. Nginx accepts LAN and Tailscale source
addresses, requires trusted TLS, and forwards HTTP streaming and WebSockets.
CLIProxy validates the shared client key. Its management API is disabled.

The listener on port 8317 and ClickHouse on ports 8123 and 9000 bind to loopback.
Provider credentials are provisioned with agenix and refreshed by CLIProxy.
The seeded Codex credential is replaced only when its encrypted seed changes;
restarting the service preserves refreshed credentials.

## Captured data

CLIProxy records client and upstream requests, responses, failed attempts, SSE
streams, and WebSocket transcripts. Its streaming logger is patched to apply
backpressure instead of dropping chunks when its queue fills. Request logging
stays enabled; log size cleanup and error-log expiry are disabled.

The pinned Plus release is `kaitranntt/CLIProxyAPIPlus` **v8.0.56-0**. It includes Codex
`response.interrupt` support and the late-interrupt fix. SSE framing is handled
upstream. The local patch retains capture backpressure and fixes object-valued
Responses `text` configuration in completion validation.

Codex providers enable WebSockets. The credential renderer also preserves a
`websockets: true` capability in the mutable Codex OAuth credential, without
replacing refreshed tokens. A live native WebSocket accepted an active interrupt
and a duplicate late interrupt, then completed the next request on the same
socket. Immediate cancellation was not established by that probe; its first
response ended with `max_output_tokens`. Both interrupt frames were logged as
handled, and the full transcript and both responses' usage reached ClickHouse.

The collector preserves every byte of each assembled request log. It stores
transcripts in 1 MiB chunks and retains complete usage objects alongside every
numeric usage field, including separate `tool_usage` model counters and unfamiliar
future categories. A manifest becomes
visible only after all chunks and usage observations have been acknowledged.
Retries are deduplicated immediately in the query views, without waiting for
ClickHouse background merges. Local logs remain available during database outages.
There is no TTL, sampling, text truncation, or scheduled capture deletion.

Only upstream usage contributes to the token views, avoiding a second count of
the downstream copy. Streaming observations retain individual categories and use
the largest reported value per upstream response and category. Cached tokens are
usually part of input, and reasoning tokens are usually part of output: adding
these categories together double-counts usage. Unknown counts remain absent.
In a real Codex CLI verification run, the CLI displayed 5,846 tokens while
ClickHouse retained 10,710 total tokens, including 4,864 cached input tokens.

The capture starts with traffic routed through this gateway. It does not backfill
old Codex sessions or intercept browser chat services and independently configured
apps. Providers may withhold usage or encrypted reasoning plaintext. In-flight
requests and long-lived WebSocket sessions reach ClickHouse after CLIProxy
assembles their logs at the end of the request or connection. Process crashes,
disk failures, and provider-side unreported usage cannot be reconstructed as
exact token counts by this collector.
Cognee's Fastembed embeddings run locally and do not emit provider API usage;
its remote LLM inference goes through the gateway.

## Storage and queries

The private browser and analytics dashboard is at
**https://ai.local.bylisa.dev/**, restricted to LAN/Tailscale and Lisa's Authentik
account. It provides full-text conversation search, model/client/date/status
filters, readable messages and tools, reported token categories, daily analytics,
and exact raw capture downloads. Requests with session IDs are grouped by
session; calls without them remain separate captures.

ClickHouse remains the canonical archive. `ai-archive.service` maintains a
disposable SQLite FTS index under its private `/var/lib/ai-archive` state directory
and refreshes it every 15 seconds (3 seconds while catching up). Indexing never
changes or deletes ClickHouse captures. Missing usage remains unknown; cached and
reasoning subsets are not added twice. Failed upstream attempts remain visible.
The backend listens only on a group-restricted Unix socket; nginx supplies the
authenticated identity. The declarative Atlas Authentik blueprint adds only this
application/provider and preserves the existing embedded outpost's providers.

CLIProxy's private configuration, mutable OAuth credentials, raw logs, and ingest
checkpoint live under `/srv/disks/projects/ai-proxy`, owned by `ai-proxy` with mode
0700. ClickHouse data lives under `/srv/disks/projects/ai-usage`, owned by
`clickhouse`. Its random password is generated once in the root-only
`/srv/disks/projects/ai-usage-secrets/clickhouse.env` and loaded by systemd.
Prompt and response text is intentionally retained in full; upstream logging
masks authentication headers.

Use `ai_usage.requests` for reconstructed transcripts, `ai_usage.usage_events`
for complete usage observations, and `ai_usage.token_counts` for deduplicated
reported counters. Do not sum `usage_observations` or raw capture tables directly.

```sql
SELECT file_name, transcript FROM ai_usage.requests LIMIT 1;

SELECT token_category, sum(token_count)
FROM ai_usage.token_counts
GROUP BY token_category;

SELECT file_name, model, usage_json FROM ai_usage.usage_events LIMIT 10;
```

## Cutover requirements

Build Nook and its deploy-rs checks before activation. Lisa approved the scoped
`nixpkgs.config.problems.handlers."gtk+".broken = "warn"` exception on Nook on
2026-11-05, preserving the existing Firestorm dependency at this Nixpkgs lock.
The host build, deployment schema, and activation checks passed before cutover.
The repository's `dendritic` check separately fails on the existing
`modules/development/ai-skills/skills/visualize/_package.nix`.

Vega disables `targets.darwin.copyApps.enable` and enables
`targets.darwin.linkApps.enable` at Lisa's request, following the
[upstream workaround](https://github.com/nix-community/home-manager/issues/8336).
The App Management preflight repeatedly reset consent, and macOS also rejected
app copying. Home Manager now manages application symlinks and completed two
consecutive activations successfully. The final system-generation switch was
also verified on 2026-11-05. The former copied-app directory is preserved under
`~/.local/state/forge-home-manager/apps-backup-20261105T142541/`.
Existing conflicting GPG backups and the local Aurora skill symlink were preserved under
`~/.local/state/forge-ai-proxy/activation-backup-20261105T140308`.

For subsequent changes, activate Nook first. Verify
`cli-proxy-api-plus`, `clickhouse`, `ai-usage-schema`, and the
`ai-usage-ingest.timer`, trusted TLS, rejection of missing API keys, and a real
request's transcript and usage in ClickHouse before switching clients. Update
Vega's system configuration to install its agenix key and host record. Restart
Codex, T3, and CLI sessions after changing provider configuration. These clients
fail when the gateway is unavailable rather than falling back to a direct route.

Codex loads its token with a [command-backed provider auth helper](https://learn.chatgpt.com/docs/config-file/config-reference),
so its key is absent from the Nix store and does not depend on GUI environment
variables. Nook's `codex` account uses the same route. T3's active Codex driver
selects that provider. Cognee uses its existing OpenRouter model through the
gateway, with a private generated client environment file.

Antigravity CLI uses [Gemini API mode and a custom endpoint](https://antigravity.google/docs/install?tab=cli).
Its wrapper reads the shared key at runtime, including when launched outside an
interactive shell. The live gateway catalog has replaced Gemini 3.7 Flash High
with `gemini-3.8-flash-high`. The client selects `Gemini 3.8 Flash (High)` by its
display name; Gemini API mode sends `gemini-3.8-flash`, which the gateway aliases
to that subscription model while retaining the original ID. Its subscription
sign-in completed on Nook on 2026-11-05;
the resulting credential is encrypted with agenix for provisioning the service.

Real Vega Codex and Antigravity CLI requests both completed through the gateway.
The Codex verification stored 14,964 total tokens, including 6,272 cached input
tokens. Antigravity's verification stored the full Gemini usage object and
request/response transcript.

Asterion is excluded from this cutover at Lisa's request. Its provider
configuration is prepared, but its runtime key must be provisioned if it is
included later. Its host key is not
yet a recipient of the shared agenix secret, so this change does not declare an
undecryptable system secret for it. Standalone Home Manager installations use
`~/.config/cli-proxy-api-plus/client-api-key`; integrated Vega/Nook configurations
read their agenix secret paths.

## Verification

```sh
nix build path:.#packages.x86_64-linux.cli-proxy-api-plus-capture --no-link
nix build path:.#checks.x86_64-linux.ai-usage-clickhouse --no-link
nix build path:.#checks.aarch64-darwin.ai-usage --no-link
nix build path:.#checks.x86_64-linux.ai-archive --no-link
```

The Linux integration check runs the real proxy against an isolated fake upstream
and a temporary ClickHouse server. It verifies non-streaming completions, streamed
Responses, WebSockets, a prompt larger than 1 MiB, complete transcripts, future
token categories, and idempotent replay. It uses synthetic credentials and incurs
no provider usage. Unit tests cover upload failures, changing logs, Unicode chunk
boundaries, partial usage, and preservation of refreshed OAuth credentials.
