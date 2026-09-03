---
name: principle-boundary-discipline
description: "Use when wiring validation, error handling, or framework adapters. Concentrate guards at system boundaries (CLI, config, network, external APIs); trust internal types and keep business logic in pure functions."
---

# Boundary Discipline

Concentrate validation, type narrowing, and translation at system boundaries. Let validated types remove redundant internal checks. Keep checks where state can change independently, persistence can drift, or the invariant is not represented by the type.

**Why:** Scattered validation is noisy, redundant, and gives a false sense of safety. Validate data once at the boundary. Keep logic out of framework wiring so it can be tested without the framework.

**The pattern:**
- **At boundaries** (CLI args, config files, external APIs, network protocols): validate, return errors, handle defensively.
- **Inside the system:** use typed data and error propagation. Avoid re-validating an invariant that the type and ownership model already preserve.
- **Across the boundary.** Expose domain concepts, not the boundary's private representation. Keep general-purpose mechanism inside and special-purpose policy at the edge.

**Applications:**

Validation and error handling:
- Validate config at parse time (the boundary), not inside business logic
- Parse raw data into domain types at the boundary
- Do not re-export transport, storage, framework, or wire types through the public surface
- No redundant nil checks deep in call chains if the boundary already validated

Code organization:
- Prefer pure business logic when side effects are not part of the domain behavior
- Parse functions: pure transforms from raw bytes to typed state
- Prompt construction: structured state in, string out
- Scoring and assessment: pure transforms from state to results

**The tests:**
- "Is this data crossing a trust or ownership boundary, or can it drift independently?" If not, validation may be redundant.
- "Can this be a pure function that the shell just calls?" If yes, extract it.
