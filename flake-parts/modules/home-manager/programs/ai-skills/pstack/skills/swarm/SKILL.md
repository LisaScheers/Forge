---
name: swarm
description: "Use only when the user invokes $swarm or explicitly asks to fan out independent slices or race several approaches in parallel."
---

# Swarm

Explicit invocation authorizes the advertised parallel subagents for the requested scope.

1. Define the done predicate, final artifact, worker count, and shape: independent slices, identical race, or mixed.
2. Prefer independent slices. For a race, declare how the winner will be selected before spawning.
3. Give each worker a standalone brief with scope, evidence requirements, verification, and output format. Assign exclusive files or output directories before any writes.
4. Spawn all workers with `collaboration.spawn_agent`. Use the parent model unless a validated `.agents/pstack-models.toml` entry applies.
5. Wait for all workers. A worker returns `PASS`, `ISSUES`, or `BLOCKED` with evidence. Proceed with dropouts and name the resulting coverage gap.
6. Verify important findings and combine results. Do not paste raw worker reports.

Return a compact coverage table, evidenced issues, gaps, and the race rule when applicable. Never fan out work that one deterministic script can do more safely.
