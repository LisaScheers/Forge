---
name: reflect
description: Spawn three parallel review subagents over the active transcript, surface learnings, and route each to a concrete edit on an existing skill. Use when the user says reflect.
---

# Reflect

Mine the current conversation for durable learnings, then route them into skill edits.

Invoke when the user says "reflect" or "/reflect". Skip when the conversation is trivial, off-topic, or already covered by an existing skill the parent followed correctly. One-offs are not learnings.

## 1. Locate the active transcript

Use Codex chat tools (`list_threads` and `read_thread`) when available, filtering to the active workspace before reading messages. For local transcripts, use `${CODEX_HOME:-$HOME/.codex}/sessions/YYYY/MM/DD/rollout-*.jsonl`; inspect only the `session_meta` fields `payload.id` and `payload.cwd` first, and read message records only after `payload.cwd` matches the active workspace. Never read unrelated project chats. Match the active chat by ID and its opening user prompt. If no transcript matches, pass a tight digest of the session instead.

## 2. Spawn three reviewers in parallel

Spawn three reviewers with `collaboration.spawn_agent`. Reviewers need MCP access to look up the tickets, chat threads, and observability traces the transcript references. Instruct them not to edit files.

Use `collaboration.spawn_agent`. Inherit the parent model and reasoning effort unless the user explicitly selects a supported override; validate any override against the current tool schema. Give read-only agents an explicit instruction not to edit files.

| Lens | Prompt template |
|---|---|
| Judgment | `references/judgment-reviewer.md` |
| Tooling | `references/tooling-reviewer.md` |
| Divergent | `references/divergent-reviewer.md` |

Pass each template verbatim, substituting the transcript path or digest where marked. Reviewers return findings in their final response.

## 3. Synthesize

Spawn one synthesizer with `collaboration.spawn_agent`, inheriting the parent model unless the user explicitly selects a supported override. It spot-verifies citations through MCP. Pass `references/synthesizer.md` verbatim, with each reviewer's full output inlined where marked. It returns an Accepted / Rejected / Backlog list.

## 4. Structural enforcement check

Move any Accepted item that a lint rule, script, metadata flag, or runtime check would enforce more reliably to Backlog. See the **encode-lessons-in-structure** principle skill.

## 5. Apply

Present the synthesizer's full Accepted / Rejected / Backlog output. A review-only request produces proposals. Apply Accepted edits when the current or earlier user request authorizes those edits; otherwise ask for approval of the proposed subset. Respect any requested checkpoint or routing change without asking again for authorization already granted.

File Backlog items to the team's tracker only when the user has authorized that external write. Otherwise return draft backlog items with the proposals. Prepare the concrete drafts before asking for any missing approval.

Follow each authorized row's Routing:

- Trivial existing-skill edit (a one-line bullet, a tightened sentence, a stale fact corrected): the parent does it directly.
- Substantive existing-skill edit (a new section, a new pattern table, more than ~10 lines): use Codex’s `skill-creator` skill and follow its current validation workflow.
- `tune description: <skill path>` (the skill exists but didn't trigger when it should have): use `skill-creator` to revise the description and check representative requests that should and should not select it.
- `new skill via skill-creator: <kebab-name>`: hand creation to `skill-creator`. Do not invent the shape ad hoc.

If your environment ships a SKILL.md validator, run it on every touched skill before declaring done.

## 6. Summarize for the user

Short list, no preamble:

- Edits applied: `<skill path>`. What changed, one line each.
- New skills created: `<skill path>`. One line each (rare).
- Backlog: distinguish draft proposals from items actually filed; link any created issues. One line each.
- Dropped: one line per rejected finding + reason from the synthesizer.
