# Coding agents

Lisa's coding agents are declared in Home Manager. One instruction file, one
skill set, one MCP catalog and one permission setup are each written once and
rendered into every client's own format. `checks.agent-policy` fails when a
rendered configuration drifts from those sources.

## Clients by host

| Client | Hosts | Module | Model route |
| --- | --- | --- | --- |
| Claude Code | Vega, Asterion, Nook (Lisa) | `modules/development/claude-code.nix` | Anthropic, direct |
| Codex CLI and desktop app | Vega, Asterion, Nook (Lisa) | `modules/development/codex/` | OpenAI, direct |
| Codex remote control | Nook (`codex` account, disabled until its login is renewed) | `modules/development/codex/nook.nix` | OpenAI, direct |
| T3 Code (Codex, Claude, Antigravity drivers) | Vega | `modules/development/t3-code/` | Each driver's own route |
| Antigravity CLI (`agy`) | Vega | `modules/development/antigravity.nix` | Nook gateway |
| Zed agent | Vega, Asterion | `modules/development/zed/` | Codex subscription; OpenRouter for commit messages |
| GitHub Copilot CLI | Instructions and skills only | `modules/development/ai-skills/default.nix` | GitHub |

Which of these routes the gateway captures is in
[the AI gateway guide](ai-usage.md#what-is-captured).

## Instructions and skills

`modules/development/ai-skills/AGENTS.md` is the global instruction file. Home
Manager writes it as `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`,
`~/.gemini/GEMINI.md` (Antigravity) and Copilot's instructions. This repository's
own rules for agents are in the root [AGENTS.md](../AGENTS.md).

Counts and MCP loading on Vega, rendered from Nix; `checks.agent-policy` fails
when this block no longer matches and prints the current version:

<!-- catalogue:start: rendered from Nix; checks.agent-policy prints the current version when this differs -->
| Skills on Vega | Claude | Codex | Antigravity | Copilot |
| --- | ---: | ---: | ---: | ---: |
| Installed | 64 | 65 | 11 | 11 |
| Of which pstack, manual only | 49 | 49 | 0 | 0 |

| MCP server | Claude | Codex |
| --- | --- | --- |
| clerk_mcp | tool search | loaded at start |
| cognee | tool search | loaded at start |
| rea | tool search | tool search |
| webmcp | tool search | loaded at start |
<!-- catalogue:end -->

| Skill set | Source | Claude | Codex | Antigravity, Copilot |
| --- | --- | --- | --- | --- |
| Bundled skills | `ai-skills/skills/` | yes | yes | yes |
| tstack (`council`, `full-send`, `full-stop`, `sol-loop`) | pinned GitHub revision | yes | yes | no |
| pstack | vendored, provenance in `ai-skills/pstack/IMPORT.md` | yes, manual only | yes, manual only | no |
| REA's `reverse-engineer-anything` | REA package | no | yes | no |

All 49 pstack skills set `allow_implicit_invocation: false` in
`agents/openai.yaml`, so Codex never loads them on its own. Claude reads the same
policy from frontmatter, so its copies gain `disable-model-invocation: true` at
build time: they run only when named and add nothing to the model's context.
`checks.agent-policy` validates every bundled and pstack `SKILL.md`: its
frontmatter, a name equal to its directory, a description within the
1,024-character limit, and the reference files it names.

## MCP servers

`modules/development/mcp.nix` declares the shared servers once: Cognee (personal
memory, OAuth through Authentik; Nook's Codex service gets it too), Clerk,
webmcp (a Nix-packaged bundle, so nothing is fetched from npm at run time), and
REA from `modules/development/rea.nix`. The catalogue above shows how each
client loads them. No MCP tool asks for approval, and `checks.agent-policy`
fails if one is set to. Every stdio server must run from the Nix store: the
check rejects package runners such as `npx` or `uvx`.

REA's 229 tool schemas measured about 3.8 MB on 2026-11-23, roughly 950,000 tokens, so neither
client loads them up front. Claude Code runs with `ENABLE_TOOL_SEARCH=true`, and
Codex marks REA `omit_tools_from = ["direct"]`; both find REA's tools through tool
search when a task needs them. `checks.agent-policy` and `checks.rea-codex-config`
fail if either setting goes away. To measure a server again, list its tools over
MCP and count the bytes of the `tools/list` result.
Both clients get the same servers; `checks.agent-policy` fails if the sets diverge.
Repository `.mcp.json` servers do not start in Claude unless enabled
(`enableAllProjectMcpServers = false`), so a cloned repository cannot add servers
on its own.

## Permissions

Lisa runs every agent with full access, by choice since 2026-11-23: no sandbox
and no approval prompts. `modules/development/agent-policy.nix` sets this in
each client's own format, and `checks.agent-policy` fails if a client starts to
sandbox or ask again.

| Client | Setting |
| --- | --- |
| Claude Code | `permissions.defaultMode = "bypassPermissions"`, no ask rules, no hooks, no bypass warning |
| Codex | `sandbox_mode = "danger-full-access"`, `approval_policy = "never"`, no rules or hooks |
| Zed | every tool allowed, unsandboxed |
| Antigravity CLI | no ask rules, access outside the workspace allowed |
| MCP servers | no approval prompts in either client |

Two limits remain, neither of which asks anything:

- **Credentials.** Claude's Read tool cannot open SSH private keys, the age
  identity, Codex's login, the gateway client key or `/run/agenix`.
- **Nesting.** `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH=1` keeps subagents from
  starting their own, AGENTS.md's no-nested-delegation rule.

AGENTS.md still tells agents to get Lisa's explicit approval in chat before
deploying, switching a daily driver, deleting memory or writing to an outside
service; nothing in the clients enforces it.

Claude's own auto memory is off, as Codex's memories are: Cognee holds memory
across sessions, and AGENTS.md says when to use it. Neither client checks for
its own updates; Nix installs both.

## What this does not protect against

With full access, nothing stands between an agent and Lisa's account except
its instructions:

- **Any command runs.** Deploys, switches, `git push`, deletions and
  third-party writes run without a prompt, in every client.
- **Shell reads.** Claude's Read deny rules stop only its Read tool; a shell
  command such as `cat ~/.config/sops/age/keys.txt` still works, in Claude and in
  Codex.
- **Network.** Every client keeps network access, so a prompt injection that gets
  a command to run can send what that command can read.

## Mutable settings

Claude Code, Codex and Antigravity use `mutableSettings`. Activation merges the
declared values into the writable files, so declared keys win, and settings an
app writes for itself survive (for example, the Codex app's own `node_repl` and
`computer-use` servers). The merge itself never removes a key, so a later step,
`codexRetireSettings`, keeps a manifest of the keys Nix declared at the last
activation in `~/.local/state/forge-agent-policy/codex-managed.json` and deletes
the ones Nix no longer declares, such as the old gateway provider
`model_providers.nook`. Keys the app or Lisa added were never in the manifest and
stay. Claude's and Antigravity's settings files have no such step; remove a key
there by hand after removing its declaration.

`checks.agent-policy` runs Home Manager's real merge and retirement steps for the
system's own home against a stale home (the earlier sandbox, ask rules and hook,
an `npx` server, the retired gateway provider, an app-owned key and server) and
requires the full-access settings to win, the old rules and provider to go, and
the app-owned entries to stay.

Because those files stay writable, every activation then runs
`agent-policy-status`, which compares the live `~/.codex/config.toml` and
`~/.claude/settings.json` with the policy and warns about each difference: the
Codex sandbox and approval mode, Claude's permission mode, or a missing
credential deny rule. Run `agent-policy-status` at any time for the same report.

## Telemetry

Claude Code and Codex send usage telemetry, without prompt or response text, to
Nook's collector ([AI gateway](ai-usage.md#usage-telemetry)).

## Verification

```sh
nix build .#checks.aarch64-darwin.agent-policy
nix build '.#homeConfigurations."lisa@vega".activationPackage' --no-link
```

The first command checks the policy, MCP catalog, tool deferral, telemetry
privacy and instruction delivery for all three of Lisa's homes and Nook's Codex
service, runs the real settings merge against a stale home, tests the drift
report and the key retirement, and validates every skill. The second builds Vega's home
without activating it.
