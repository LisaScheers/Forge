---
name: principle-foundational-thinking
description: "Use when a change depends on a lasting data shape, shared state, or setup that affects later phases. Choose the smallest foundation that makes the requested work safer or simpler."
---

# Foundational Thinking

**Structural decisions** protect option value. **Code-level decisions** protect simplicity. Over-engineering is often a premature decision that closes doors. The right foundational data structure keeps doors open.

**Data structures first when they are load-bearing.** Name the important shape before writing stateful or branch-heavy logic. Trace the access patterns that matter to this change and choose a structure that fits them. Keep plain local values when no lasting model is needed.

At code level, DRY the structure, not every line. Types and data models should converge. Three similar statements still beat a premature abstraction. Prefer explicit over clever. Test behavior and edge cases, not line counts.

**Concurrency corollary.** Before sharing state between actors, ask "what happens if another actor modifies this concurrently?" If not "nothing", isolate.

**Scaffold first when later work depends on it.** Ask whether every later phase needs the setup. Shared types, a focused test harness, or generated inputs may qualify. Do not add general CI, linting, or framework infrastructure for a local change unless the task requires it.

Each increment should land a coherent abstraction or deepen one that exists. Do not spread a new capability across callers as special-case coordination.

Subtraction comes before scaffolding: remove dead weight first, then lay foundations.
