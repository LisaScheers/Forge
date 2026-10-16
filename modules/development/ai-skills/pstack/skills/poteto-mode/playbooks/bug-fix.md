# Bug fix

**You own this task. Plan, investigate, fix, and verify.** Delegate only an independent bounded part whose coordination cost is justified.

Be scientific. Every shipped line traces to runtime evidence. Belt-and-suspenders that "might help" is a hypothesis, not a fix; it does not ship. When evidence refutes a hypothesis, revert what it motivated. The smallest change the evidence justifies ships, nothing more. Same discipline for Perf, where the evidence is the trace.

1. Reproduce the defect on the matching surface when the environment permits it. Otherwise establish the failure from the strongest available artifact, such as a focused failing test, trace, or log. Ask the user only when required state or access cannot be obtained locally.
2. Form candidate causes and rule them out with evidence until one mechanism remains. Use `how` when the runtime path is unclear. Use **why** only when recorded regression history could change the diagnosis. Add focused instrumentation when state is otherwise ambiguous.
3. Plan the smallest fix supported by the evidence. Use `architect` only for a hard-to-reverse boundary or ownership change. When delegation is authorized and useful, give the subagent a bounded scope and verification contract, inherit the parent model unless repository configuration supplies a supported model and reasoning effort separately, and review the diff.
4. Verify on the same surface; the original repro now passes. "Inconclusive" or wrong-surface is not a pass; flag it. Unit tests show branch behavior, not bug absence.
5. Stage the commits so the failing repro lands before the fix in git history; the diff tells the story. See the **tdd** skill for the failing-test-first cadence when the bug has a cheap local test path; skip it when the test would be expensive, integration-heavy, or unclear.
   This is the canonical **sequence-verifiable-units** principle skill, the failing test first and the fix on top.
6. Run **Opening a PR** only when the user asked for a pull request.

Parallelize investigation only when the hypotheses are independent and the task benefits enough to justify coordination.

**Reply:** what was broken, root cause, fix, how you verified. Paste failing-then-passing repro output verbatim.
