# Decisions: coding agents and AI services

Each entry records a choice that shapes Lisa's agent setup, why it was made, and
what it costs. The guides describe the current state; this file explains it.
Newest first.

## 2026-11-23: agents run with full access and no prompts

**Decision.** Claude Code starts in `bypassPermissions`, Codex runs
`danger-full-access` with `approval_policy = "never"`, Zed allows every tool
unsandboxed, Antigravity may leave its workspace, and no MCP tool asks first.

**Why.** Lisa's choice: she does not want sandboxes or approval prompts. An
approval policy with hooks and prefix rules was built and then removed at her
request (commit `8861a0a`).

**Cost.** Deploys, deletions and third-party writes run without a prompt; shell
commands can read credential files; every client keeps network access. AGENTS.md's
approval rules are instructions, not enforcement. Two limits that never prompt
remain: Claude's Read tool cannot open credential files, and subagents cannot nest.
[Coding agents](agents.md#what-this-does-not-protect-against) lists the gaps.

## 2026-11-23: Claude Code's OS sandbox stays off

**Decision.** Claude Code's built-in Bash sandbox is not enabled.

**Why.** It confines writes to the working directory. A T3 worktree commits to
the main checkout's `.git`, outside that directory, so routine commands would fail
and retry unsandboxed. Lisa declined it before choosing full access.

**Cost.** Superseded by full access; recorded so the option is not re-proposed
without that context.

## 2026-11-23: direct clients send usage telemetry, not transcripts

**Decision.** Claude Code and Codex send OpenTelemetry metrics and events to a
collector on Nook (`modules/services/ai-proxy/telemetry.nix`), which writes them
to ClickHouse's `otel` database through an account that can only create and fill
that database. Prompt, response and tool text stay out.

**Why.** Both clients sign in to their providers directly, so the gateway never
sees their traffic; telemetry restores usage visibility without copying content.

**Cost.** Token counts and costs, not readable conversations. The endpoint has
no client credential, because Codex can only send static headers, which would put
a secret in the Nix store; LAN and Tailscale limits, a size limit and a rate limit
bound abuse. The collector is built with Go 1.26 until Nixpkgs fixes its vendored
`cockroachdb/swiss` for Go 1.27.

## 2026-11-23: MCP tools are found through tool search, not loaded

**Decision.** Claude runs with `ENABLE_TOOL_SEARCH=true`; Codex marks every
server `omit_tools_from = ["direct"]`. All servers stay installed in both clients.

**Why.** REA alone has 229 tool schemas, about 950,000 tokens. Deferral keeps
first requests near 46,000 tokens in Claude and 28,000 in Codex (measured with
`agent-context-baseline`) without making Lisa attach servers per project.

**Cost.** A task's first use of a server costs one tool search.

## 2026-11-23: settings files stay writable, and Nix retires its own keys

**Decision.** Claude, Codex and Antigravity keep `mutableSettings`. After each
merge, `codexRetireSettings` deletes keys Nix declared before and no longer
declares, using a manifest per file; `agent-policy-status` reports any remaining
drift.

**Why.** The apps write their own settings (the Codex app's `node_repl` and
`computer-use` servers, desktop preferences), which immutable files would break.
Home Manager's merge never removes keys, which left the old gateway provider in
Codex's config.

**Cost.** A key Lisa adds by hand under a name Nix later stops declaring is
removed with it.

## 2026-11-23: Cognee's backup leaves Nook as ciphertext

**Decision.** Nook writes a nightly archive of Cognee's state encrypted to Lisa's
age key; Atlas pulls it with a key whose forced command can only print it
(`modules/services/cognee/backup.nix`).

**Why.** Atlas is internet-facing. It should hold a copy it cannot read.

**Cost.** Restores need Lisa's age identity. Cognee stops for the length of the
copy at 03:15 UTC. Atlas's pull starts once the module reaches `main`.

## 2026-11-23: the archive reads ClickHouse through a read-only account

**Decision.** The AI archive web app uses `ai_archive`, which ClickHouse limits
to `SELECT` on `ai_usage` in read-only mode
(`services/ai-usage/clickhouse-users.xml`).

**Why.** It previously used the `default` superuser and relied on its own HTTP
client to ask for read-only mode.

## 2026-11-23: no shell-wide gateway variables

**Decision.** `OPENAI_BASE_URL` and `ANTHROPIC_BASE_URL` are no longer exported to
every shell; each gateway client (Antigravity, Cognee) sets its own route.

**Why.** Clients that sign in directly could follow those variables to a gateway
that holds no credentials for them; Claude Code needed a wrapper to undo one.

## 2026-11-23: Cognee is the only memory

**Decision.** Claude's auto memory and Codex's memories are off; both use Cognee
through MCP, as AGENTS.md describes.

**Why.** One memory with dated sources that every client shares, instead of a
separate store per client.

## 2026-11-20: Codex traffic is no longer captured

**Decision.** The patched Codex build that saved raw API responses, and its
upload job, were removed (commit `fbf67bc`). Codex uses its built-in `openai`
provider.

**Cost.** Codex transcripts exist only in local session files; usage reaches
ClickHouse through telemetry since 2026-11-23.
