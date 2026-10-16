---
name: figure-it-out
description: "Use only when the user invokes $figure-it-out or an active workflow needs an auditable plan for a large migration or multi-part change that no narrower playbook covers."
---

# Figure it out

When a broad task matches no playbook, design one. The deliverable before code is a sequence of phases that scales rigor to the task, tests important assumptions, and leaves a decision trail when a human will review the work later.

Don't reinvent a playbook you already have. A focused single-unit task that matches Bug fix, Perf, Feature, Visual parity, Eval, or Multi-phase plan routes there. But a large or cross-cutting version of one (a migration across many call sites, an ambitious multi-part change), or work the user reviews after stepping away, belongs here even though a single-unit version would be a Feature. The rigor and the audit trail are the point.

## Start

Use `update_plan` with the phases below. Read only the principle skills that resolve a concrete decision.

## Phase A: Frame

Ground first, then commit. Don't start the run until you can state:

- The definition of done as a falsifiable predicate (the **prove-it-works** principle skill). "Done well" has to be checkable.
- Scope, quantified: rough units and effort, plus the blockers grounding surfaced. Raise them before spending hours, not after fifty doomed commits.
- The rigor level. One-way doors and high blast radius get more; reversible low-stakes steps get less. Rigor is evidence and gates, not extra ceremony.

Present the framing and tradeoffs before committing to a long run. Reversible work proceeds (the **never-block-on-the-human** principle skill), but a multi-hour run earns one checkpoint.

## Phase B: Design the workflow

Decompose into atomic, independently-landable units. Sequence riskiest-unknown-first so option value stays high. Scaffold and verification come before features (the **foundational-thinking** principle skill).

- Build a verification harness before the work when existing checks cannot prove the completion predicate. Capture a baseline when the result needs an old-versus-new comparison.
- For one-way-door design decisions, run the **architect** skill. Use **arena** only when the user requests competing candidates. Skip both for mechanical work whose shape is already concrete.
- Decide what fans out. Parallelize only across genuine seams, and give each worker its own worktree or branch (the **separate-before-serializing-shared-state** principle skill). Don't over-fan.
- Write the designed phase list down. That list is what the human reviews.

Then put the design into motion. Add its steps to `update_plan` as concrete items, after the Phase C entry and before Phase D. Run each under the Phase C loop discipline, and weave the Phase D log through them, a row as each step lands, rather than saving the whole trail for the end.

## Phase C: Run the loop

Each unit is an experiment: state the hypothesis, make the smallest change, measure against the predicate on the real artifact, keep it if it advanced, revert it if it didn't.
Apply the **sequence-verifiable-units** principle skill. Verify before dependent work builds on an uncertain result, and run an integrated check at the end.

- Verify by inspecting the artifact, never a self-report. When something passes too easily, suspect the observation method before the system. A blank screenshot passes a lazy gate.
- Audit delegated artifacts yourself. Add an independent judge only when the user requested adversarial review or the risk justifies it.
- A verdict is VERIFIED, NOT VERIFIED, or INCONCLUSIVE. Inconclusive is not a pass. Don't hide a negative.

## Phase D: Keep the audit trail

Log the run via `$show-me-your-work`, one canonical TSV with a row per decision and per unit, evidence as links. Keep it local unless the user asks to commit it. Prefer evidence produced by durable scripts when a reviewer needs to rerun the proof. The trail plus the diff is what lets the human come back and trust the work.

## Phase E: Verify and hand back

Check the whole against the Phase A predicate on the real product, not just the harness. When a correction has recurred and the requested scope includes a durable fix, encode it as a gate, lint rule, check, or script.

**Reply:** the playbook you designed, the rigor level and why, the decision-trail path, what's verified against the predicate, and what's still open.
