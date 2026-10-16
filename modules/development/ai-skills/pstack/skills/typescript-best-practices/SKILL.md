---
name: typescript-best-practices
description: Use when implementing or reviewing TypeScript types, public APIs, or untrusted-data boundaries, or when answering a TypeScript type-design question. Do not use for incidental file reads.
---

# TypeScript best practices

Follow the repository's TypeScript conventions first. Use types to prevent real mistakes without adding ceremony that the code does not need.

- Prefer inference and derive types from authoritative schemas or existing functions.
- Treat untrusted external data as `unknown` until a boundary parser validates it.
- Use discriminated unions when variants have different valid fields or behavior.
- Make variant handling exhaustive when a missed case would be a bug.
- Avoid `any`. Isolate it at an unavoidable third-party boundary and explain why it cannot be narrowed.
- Prefer narrowing, `satisfies`, and schema validation over broad assertions.
- Keep a necessary assertion local. Use it only when runtime evidence or an upstream contract establishes a fact that TypeScript cannot express.
- Brand primitive values when accidental mixing is plausible and costly, not for every identifier.
- Strengthen a collection or value type only where the looser type makes an operation partial or repeatedly forces a guard.
- Prefer object arguments when several similar positional values are easy to swap. Keep simple positional APIs when their meaning is obvious.
- Validate once at an untrusted boundary. Internal checks still belong where state can change independently, persistence can drift, or a lower-level invariant is not represented by the type.

Use focused tests for runtime behavior. Type checks prove the static contract, not parsing, side effects, or user-visible behavior.

Read [references/patterns.md](references/patterns.md) only when a concrete type-design problem needs an example.
