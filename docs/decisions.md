# Decisions: coding agents and AI services

Each entry records a choice that shapes Lisa's agent setup, why it was made, and
what it costs. The guides describe the current state; this file explains it.
Newest first.

## 2026-11-23: Claude attaches REA only when a session needs it

**Decision.** Claude no longer starts REA by default; `claude --mcp-config
~/.claude/mcp-available/rea.json` attaches it. Codex keeps it. This narrows the
tool-search decision below for one server in one client.

**Why.** Claude's tool search still lists every deferred tool's name, and REA's
229 names cost about 6,000 tokens in every session, while few sessions
reverse-engineer anything. Codex's deferred servers cost nothing up front.

**Cost.** A reverse-engineering session in Claude has to start with the flag.

## 2026-11-23: session files are backed up to Nook, encrypted

**Decision.** Vega backs up its Claude and Codex session files to Nook daily
with restic; the repository password is encrypted to Lisa's age key.

**Why.** Those files are the only transcripts of the two main clients since
Codex capture was removed. Lisa chose an encrypted copy over a searchable one.

**Cost.** The AI archive cannot search them; restoring needs Lisa's age identity.

## 2026-11-23: no custom subagents or commands

**Decision.** Lisa's agents get shared instructions and skills, but no custom
subagents or slash commands of their own.

**Why.** Lisa's choice. Her instructions already limit delegation, and skills
cover the repeatable workflows.

## 2026-11-23: skills are installed globally, not linked per repository

**Decision.** Every skill is installed for its clients in every directory; no
repository-scoped skill groups.

**Why.** The index a client lists up front, the names and descriptions of skills
the model may load on its own, is about 850 tokens in Claude and Codex
([context budget](skills.md#context-budget)), under 2% of a session's first
request. All 49 pstack skills are manual-only and add nothing up front. Per-repo
linking would save little and add a direnv hook to every project.

**Cost.** Domain skills such as `aurora-viewer-control` are listed in unrelated
repositories too. Revisit if the index grows past a few thousand tokens.

## 2026-11-23: Zed and Antigravity get only small MCP servers

**Decision.** Zed's agent and Antigravity get `mcp-nixos` and webmcp; REA,
Cognee and Clerk stay with Claude and Codex.

**Why.** Neither client has tool search, so every schema loads up front, and
REA's would be about 950,000 tokens. Cognee and Clerk sign in through OAuth.

## 2026-11-23: rendered agent settings are snapshotted

**Decision.** `tests/agent-config/` keeps a normalised snapshot of each home's
rendered agent settings, and `checks.agent-policy` fails when one changes.

**Why.** Several modules contribute to each client's settings; a snapshot makes
the combined result reviewable as a diff instead of trusting each module alone.

**Cost.** A deliberate change needs `nix build .#agent-config-snapshots` and a
copy into `tests/agent-config/`.

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
server `omit_tools_from = ["direct"]`. All servers stay installed in both clients
(Claude attaches REA on demand since; see above).

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

## 2026-11-24: Cognee's backup stays on Nook

**Decision.** Nook writes a nightly archive of Cognee's state encrypted to Lisa's
age key and keeps it on Nook (`modules/services/cognee/backup.nix`). No other
host copies it. This replaces the 2026-11-23 plan, never deployed, for Atlas to
pull the ciphertext.

**Why.** Lisa did not approve the Atlas copy and does not want her data on a
public cloud host, even encrypted.

**Cost.** Restores need Lisa's age identity. Cognee stops for the length of the
copy at 03:15 UTC. The archive does not survive the loss of Nook's projects disk.

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
