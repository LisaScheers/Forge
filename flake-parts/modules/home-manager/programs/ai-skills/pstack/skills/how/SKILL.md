---
name: how
description: Use when the user asks how a subsystem or feature works, requests a code walkthrough, or asks where code should live or which component owns it. Use why for recorded historical rationale.
---

# How

Inspect the codebase and give the user a working mental model. This is read-only unless the user separately asks for changes.

## Explore

Interpret the narrowest useful scope from the request and conversation. State a material assumption, then proceed.

Explore directly in the current task by default:

1. Find the entry point and the important types or state.
2. Trace the path from trigger or input to effect or output.
3. Read the code that makes each material decision.
4. Stop when the full path can be explained without guessing.

For a broad question that spans independent subsystems, split the reads by subsystem and run them concurrently when the tooling supports it. Use subagents only when the user requested parallel work or the breadth justifies their coordination cost. Give each one a read-only scope and synthesize the result yourself.

## Explain

Lead with the answer. Then include only the sections the question needs:

- the main flow in execution order;
- the types, services, or boundaries needed to understand it;
- the files and symbols that let the user continue exploring;
- non-obvious behavior or sharp edges.

Use file and symbol references as evidence. Do not turn the answer into an inventory of functions.

When the user asks for architectural criticism, explain the current design first. Review it locally by default. Use multiple independent critics only when the user asks for adversarial or multi-agent review.

Stop when the user can answer what triggers the behavior, where state moves, which decisions change the path, and which component owns the result.
