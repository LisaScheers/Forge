---
name: principle-sequence-verifiable-units
description: "Use when a sweep, migration, or other multi-step change needs dependency-aware batches that can be verified independently."
---

# Sequence work into verifiable units

Order dependent work as units that end in a state you can check. Choose the unit size that localizes failures without turning a mechanical transformation into unnecessary ceremony.

**Why:** A break caught at the unit that caused it is cheap to localize. A break caught after a batch is buried, and you have already built further on a broken base. Sequencing those same units into a delivery a reviewer can replay turns "trust me" into "watch it go red, then green."

**Execution.** Verify before building dependent work on top of an uncertain result. Batch deterministic mechanical edits when one tool applies the same rule and targeted checks can identify failures. Use smaller units for judgment-heavy changes or when failures would be hard to localize.

**Delivery.** Stack commits and PRs in the order that proves the work. The canonical shape is the failing test first, then the fix on top. The first unit shows the bug is real (red), the next shows it resolved (green), so a reviewer sees both the problem and the proof. Other story orders are a subtraction before the reshape, a baseline capture before the treatment, the scaffold before the feature. Each commit lands on its own and the sequence reads as an argument.

**Pattern:**
- Pick the smallest unit that ends in a check: an edit plus its test, or a commit that stands alone.
- Verify before advancing to work that depends on the result. A final integrated check still covers the complete change.
- Order the units so the sequence builds confidence on its own, for you while executing and for a reviewer reading the stack.

The sequencing complement to the **prove-it-works** principle skill, which keeps each check real, and the **build-the-lever** principle skill, which makes the per-unit check cheap.
