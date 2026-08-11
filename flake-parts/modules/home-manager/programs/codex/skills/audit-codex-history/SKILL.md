---
name: audit-codex-history
description: Review Codex history for repeated mistakes and propose better instructions. Use when the user asks to audit history, improve AGENTS.md, or find recurring agent problems.
---

# Audit Codex History

Review a meaningful sample of past conversations and identify mistakes that repeat often enough to deserve a durable instruction.

Track counts by model and harness when the history contains more than one. Useful categories from the video include:

- user corrections per hundred messages;
- killing the wrong process or mishandling a stale process;
- touching user data or changing files in response to a question;
- poor pull request hygiene, stale branches, drafts, or missed CI failures;
- unnecessary repository-wide checks;
- shell and tool-use errors;
- overbuilding, extra abstractions, or edits outside the request;
- stopping before the requested outcome;
- claiming completion without verification;
- introducing regressions.

Read enough surrounding context to understand each event. A failed command is not automatically an agent mistake, and a user correction is not automatically proof that the earlier decision was unreasonable.

For questionable decisions, ask what evidence led the agent in that direction. For tasks that took much longer than expected, group the tool calls and distinguish the useful work from detours.

Report the most frequent patterns, their approximate frequency, examples, and whether they appear specific to one model or harness. Then propose small edits to `AGENTS.md` or narrowly triggered skills. Prefer a concrete rule with a good or bad example over a broad warning.

Present the proposals for review before editing the managed files. The goal is not to grow the prompt forever; it is to remove repeated friction with the smallest useful change.
