### Feature

**You own the design, implementation, and verification.** Delegate only when the work divides into an independent bounded unit whose coordination cost is justified.

1. Inspect the affected subsystem. Use `how` when the runtime path or ownership is unclear.
2. Use `architect` only for a hard-to-reverse ownership or boundary decision with several viable shapes.
3. For work large enough to benefit from parallelism, write a throughput checkpoint before delegating:
   - **Blocking first steps.** Gates run before fan-out.
   - **Independent workstreams.** Disjoint files, services, or layers parallelize. Shared writes serialize.
   - **Shared mutable state.** Default to splitting the target (the **separate-before-serializing-shared-state** principle skill). Serialize only for real invariants.
   - **Smallest safe decomposition.** If one worker is best, name why.
4. Implement the smallest coherent change. Name the data shape and success criteria before writing logic. When delegation is authorized and useful, give the subagent exclusive files, the named shape, the behavior to preserve, and the verification contract. Inherit the parent model unless repository configuration supplies a supported model and reasoning effort as separate settings. Use **arena** only when the user requests competing candidates. Review every delegated diff before accepting it. Re-ground against the source for upstream-derived files and verify affected consumers.
5. Verify on the matching surface. "Inconclusive" or wrong-surface is not a pass; flag it.
6. Keep the change in coherent, verifiable units. Rebase or stack only when the requested delivery workflow needs it.
7. If the design is contested, `interrogate` before shipping.
8. Run **Opening a PR** only when the user asked for a pull request.

Code-coupled work normally stays with one owner. Parent-level fan-out is for slices that produce independent artifacts, such as audits, cross-subsystem investigations, or explicitly requested competing experiments.

**Reply:** what you built, what you chose and why, open decisions. Tables for design alternatives.
