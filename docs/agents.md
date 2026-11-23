# Coding agents

Lisa's coding agents are declared in Home Manager. One instruction file, one
skill set, one MCP catalog and one approval policy are each written once and
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

`modules/development/mcp.nix` declares the shared servers once.

| Server | Claude | Codex | Approval |
| --- | --- | --- | --- |
| Cognee (personal memory, OAuth through Authentik) | yes | yes, and Nook's service | `forget` asks in both |
| Clerk | yes | yes | every tool asks in both |
| REA (`modules/development/rea.nix`) | yes, through tool search | yes, through tool search | client default |
| webmcp (Nix-packaged bundle, no npm fetch at runtime) | yes | yes | client default |

REA's 229 tool schemas measure about 3.8 MB, roughly 950,000 tokens, so neither
client loads them up front. Claude Code runs with `ENABLE_TOOL_SEARCH=true`, and
Codex marks REA `omit_tools_from = ["direct"]`; both find REA's tools through tool
search when a task needs them. `checks.agent-policy` and `checks.rea-codex-config`
fail if either setting goes away. To measure a server again, list its tools over
MCP and count the bytes of the `tools/list` result.
Both clients get the same servers; `checks.agent-policy` fails if the sets diverge.
Repository `.mcp.json` servers start in Claude only after approval
(`enableAllProjectMcpServers = false`).

## Approval policy

`modules/development/agent-policy.nix` holds the policy:

- **Live-system commands need Lisa.** `just switch`, `just deploy`,
  `scripts/deploy.sh`, `darwin-rebuild switch`, `nixos-rebuild switch`,
  `home-manager switch`, the same through `nix run`, deploy-rs and
  `nixos-anywhere`. This puts AGENTS.md's rule into the clients: deployments and
  daily-driver builds need Lisa's approval.
- **Credentials are never read.** SSH private keys, the age identity, Codex's
  login, the gateway client key and `/run/agenix`.
- **Tools that delete or act as Lisa ask first.** Cognee `forget`, every Clerk
  tool, and the claude.ai connector tools that send mail or messages, publish,
  or delete (Microsoft 365 and Shopify).
- **Subagents do not start subagents.** AGENTS.md's no-nested-delegation rule.

| Client | How the policy is applied |
| --- | --- |
| Claude Code | `permissions.ask` and `permissions.deny`, plus a PreToolUse hook (`agent-policy/approval_hook.py`) that asks for these commands after `cd x &&`, `sudo`, `nix run` or a pipe, in every mode including bypass, and denies Agent and Task calls from subagents |
| Codex | `workspace-write` sandbox with network access and `on-request` approval, `rules/agent-policy.rules` prefix rules that prompt, and the same hook. Codex hooks cannot ask, so in modes that never prompt (T3 full access, `--profile full`) the hook blocks these commands; approve them in a mode that prompts |
| Zed | `always_confirm` regexes for the terminal tool |
| Antigravity CLI | `permissions.ask`; access outside the workspace is off |

Codex has no read rules: its sandbox limits writes, not reads. For one
unsandboxed Codex session, run `codex --profile full`. T3 Code sets the runtime
mode per thread, independently of these defaults.

Claude's own auto memory is off, as Codex's memories are: Cognee holds memory
across sessions, and AGENTS.md says when to use it.

## Mutable settings

Claude Code, Codex and Antigravity use `mutableSettings`. Activation merges the
declared values into the writable files, so declared keys win, and settings an
app writes for itself survive (for example, the Codex app's own `node_repl` and
`computer-use` servers). Removing a declaration does not remove the key from the
file; delete it by hand after removing it from Nix.

`checks.agent-policy` runs Home Manager's real merge steps for the system's own
home against a stale home (full access, no rules, an `npx` server, an app-owned
key) and requires the policy to win and the app-owned keys to survive.

Because those files stay writable, every activation then runs
`agent-policy-status`, which compares the live `~/.codex/config.toml` and
`~/.claude/settings.json` with the policy and warns about each difference: the
Codex sandbox and approval mode, missing Claude ask and deny rules, or a missing
approval hook. Run `agent-policy-status` at any time for the same report.

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
service, runs the real settings merge against a stale home, tests the hook and
the drift report, and validates every skill. The second builds Vega's home
without activating it.
