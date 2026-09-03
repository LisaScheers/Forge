---
name: no-comments
description: "Use only when the user invokes $no-comments or explicitly asks to audit comments and suppressions in a diff."
---

# No comments

Review comments rather than applying a blanket deletion rule.

1. Scope the current diff or the files named by the user.
2. Classify each comment as rationale, external constraint, public API documentation, generated annotation, suppression, narration, stale explanation, or workaround warning.
3. Keep comments that explain non-obvious behavior, usage, safety constraints, or an external limitation the code cannot encode.
4. Remove narration that merely repeats the code and stale text contradicted by the implementation.
5. For a claimed invariant, prefer an appropriate type, test, lint rule, or runtime check when that makes the rule enforceable without adding more complexity.
6. Treat lint and type suppressions as correctness work. Do not delete one unless the underlying issue is fixed or the suppression is proven unnecessary.

Review is read-only unless the user asked to clean the comments. Never spawn an unavailable custom reviewer type. Use an ordinary read-only subagent only when the user explicitly requests an independent comment review.
