---
name: principle-guard-the-context-window
description: "Use when context is filling up: large outputs, long files, repeated reads, fan-out planning. Route bulk to subagents; keep summaries in the main thread, not raw payloads."
---

# Guard the context window

Context is finite even when the harness can compact history or preserve reasoning between turns. Every token should earn its place, and compacted state should remain functionally consistent with the task.

**Why:** Context overflow degrades reasoning quality, creates compression artifacts, and halts progress. Unlike compute or time, context spent inside a session cannot be reclaimed.

**Pattern:**
- **Reduce large payloads.** Limit command output, search selectively, and summarize structured results before adding them to the main context.
- **Don't read what you won't use.** Read selectively based on relevance. If a file isn't needed for the current task, skip it.
- **Keep frequently used content inline.** Templates and references used on every invocation belong in the skill file, not in separate files that cost a read each time.
- **Size phases and cap scope.** Limit files per phase, set turn budgets, account for mechanism costs.
- **Delegate for work shape, not token hiding.** Use subagents only when the task divides into independent workstreams and delegation is authorized. A large file alone is not a reason to delegate.
- **Compact at milestones.** Preserve the objective, constraints, decisions, remaining work, and evidence. Do not repeatedly reread completed work after compaction.
