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
| pstack | vendored, provenance in `ai-skills/pstack/IMPORT.md` | no | yes | no |
| REA's `reverse-engineer-anything` | REA package | no | yes | no |

The 24 `principle-*` pstack skills set `allow_implicit_invocation: false`, so
Codex never loads them on its own; they run only when named.
`checks.agent-policy` validates every bundled and pstack `SKILL.md`: its
frontmatter, a name equal to its directory, a description within the
1,024-character limit, and the reference files it names.

## MCP servers

`modules/development/mcp.nix` declares the shared servers once.

| Server | Claude | Codex | Approval |
| --- | --- | --- | --- |
| Cognee (personal memory, OAuth through Authentik) | yes | yes, and Nook's service | `forget` asks in both |
| Clerk | yes | yes | every tool asks in both |
| REA (`modules/development/rea.nix`) | yes | yes | client default |
| webmcp (Nix-packaged bundle, no npm fetch at runtime) | no | yes | client default |

Claude Code loads MCP tool schemas on demand through tool search, so REA's
roughly 300 tools do not fill the context of Claude sessions that never use them.
Repository `.mcp.json` servers start in Claude only after approval
(`enableAllProjectMcpServers = false`).

## Approval policy

`modules/development/agent-policy.nix` holds the policy:

- **Live-system commands ask first.** `just switch`, `just deploy`,
  `scripts/deploy.sh`, `darwin-rebuild switch`, `nixos-rebuild switch`,
  `home-manager switch`, deploy-rs and `nixos-anywhere`. This puts AGENTS.md's
  rule into the clients: deployments and daily-driver builds need Lisa's approval.
- **Credentials are never read.** SSH private keys, the age identity, Codex's
  login, the gateway client key and `/run/agenix`.
- **Destructive MCP tools ask first.** Cognee `forget` and every Clerk tool.

| Client | How the policy is applied |
| --- | --- |
| Claude Code | `permissions.ask` and `permissions.deny`, plus a PreToolUse hook (`agent-policy/approval_hook.py`) that also catches these commands after `cd x &&`, `sudo` or a pipe, and in bypass mode |
| Codex | `workspace-write` sandbox with network access and `on-request` approval, plus `rules/agent-policy.rules` prefix rules that prompt |
| Zed | `always_confirm` regexes for the terminal tool |
| Antigravity CLI | `permissions.ask`; access outside the workspace is off |

Codex has no read rules: its sandbox limits writes, not reads. For one
unsandboxed Codex session, run `codex --profile full`. T3 Code sets the runtime
mode per thread, independently of these defaults.

## Mutable settings

Claude Code, Codex and Antigravity use `mutableSettings`. Activation merges the
declared values into the writable files, so declared keys win, and settings an
app writes for itself survive (for example, the Codex app's own `node_repl` and
`computer-use` servers). Removing a declaration does not remove the key from the
file; delete it by hand after removing it from Nix.

## Verification

```sh
nix build .#checks.aarch64-darwin.agent-policy
nix build '.#homeConfigurations."lisa@vega".activationPackage' --no-link
```

The first command checks the policy, MCP catalog and instruction delivery for all
three of Lisa's homes and Nook's Codex service, runs the hook's tests and
validates every skill. The second builds Vega's home without activating it.
