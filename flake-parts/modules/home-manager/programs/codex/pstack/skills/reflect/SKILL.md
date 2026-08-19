---
name: reflect
description: Spawn three parallel review subagents over the active transcript, surface learnings, and route each to a concrete edit on an existing skill. Use when the user says reflect.
---

# Reflect

Mine the current conversation for durable learnings, then route them into skill edits.

## When to invoke

- The user said "reflect" or `$reflect`.
- A complex task (5+ tool calls) just landed cleanly and the recipe is worth keeping.
- The agent hit dead ends, found the working path, and the path generalizes.
- The user corrected the agent's approach mid-task.
- A non-trivial workflow emerged that isn't captured anywhere.

Skip when the conversation is trivial, off-topic, or already covered by an existing skill the parent followed correctly. One-offs are not learnings.

## Process

### 1. Locate the active transcript

The parent finds its own transcript file before fanning out. Search `~/.codex/sessions/` and `~/.codex/archived_sessions/` for the active workspace path. Do not scan unrelated workspaces.

```bash
rg -l -0 -F "$WORKSPACE" "$HOME/.codex/sessions" "$HOME/.codex/archived_sessions" |
while IFS= read -r -d '' session; do
  jq -r '
    select(
      .type == "response_item" and
      .payload.type == "message" and
      (.payload.role == "user" or .payload.role == "assistant")
    )
    | .payload as $message
    | $message.content[]?
    | select(.type == "input_text" or .type == "output_text")
    | (.text // empty)
  ' "$session"
done
```

Three transcript layouts: legacy flat (`<id>.jsonl`), current nested (`<id>/<id>.jsonl`), and subagent (`<parent>/subagents/<child>.jsonl`).

For each candidate, locate its first user message and check that it contains the conversation's opening prompt. Take the matching path. If no path resolves, write a tight digest of the session and pass that instead.

### 2. Spawn three reviewers in parallel

Spawn three reviewers with `collaboration.spawn_agent`, `fork_turns: "none"`, and the parent model. The prompt forbids file writes; the parent applies approved edits.

| Lens | Prompt template |
|---|---|
| Judgment | `references/judgment-reviewer.md` |
| Tooling | `references/tooling-reviewer.md` |
| Divergent | `references/divergent-reviewer.md` |

Pass each template verbatim, substituting the transcript path or digest where marked. Reviewers return findings to the parent.

### 3. Synthesize

Spawn one synthesizer with `collaboration.spawn_agent`, `fork_turns: "none"`, and the parent model. Use `references/synthesizer.md` verbatim, with each reviewer's full output inlined where marked. Tell it to make no edits or external writes. It returns a structured Accepted / Rejected / Backlog list.

### 4. Structural enforcement check

Sanity-check the synthesizer's Accepted list. For any item that would be enforced more reliably by a lint rule, script, metadata flag, or runtime check, move it from Accepted to Backlog. The synthesizer already applies this criterion; this is a final pass before edits land. See the **encode-lessons-in-structure** principle skill.

### 5. Apply

Before applying any Accepted edit, present the synthesizer's full Accepted/Rejected/Backlog output to the user and wait for explicit approval. The user picks which subset to apply and may redirect routings. Skill changes affect every future agent in the org; do not auto-apply.

Do not file Backlog items automatically. Present them with the Accepted list and wait for explicit approval before any external write.

For each approved Accepted item, follow the Routing field exactly:

- Trivial existing-skill edit (a one-line bullet, a tightened sentence, a stale fact corrected): parent does directly.
- Substantive existing-skill edit (a new section, a new pattern table, more than ~10 lines): use `$skill-creator` and run its draft / test / iterate loop.
- `tune description: <skill path>` (the skill exists but didn't trigger when it should have): use `$skill-creator` and run its description-optimization loop.
- `new skill via skill-creator: <kebab-name>`: use `$skill-creator`. Do not invent the shape ad hoc.

If your environment ships a SKILL.md validator, run it on every touched skill before declaring done. Skip this step if it doesn't.

### 6. Summarize for the user

Short list, no preamble:

- Edits applied: `<skill path>`. What changed, one line each.
- New skills created: `<skill path>`. One line each (rare).
- Backlog filed to the devex tracker: `<issue title>` (`<tags>`). One line each.
- Dropped: one line per rejected finding + reason from the synthesizer.
