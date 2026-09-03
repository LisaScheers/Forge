---
name: architect
description: Use only when the user explicitly asks for architecture or an active workflow reaches a hard-to-reverse ownership or module-boundary decision with several viable shapes.
---

# Architect

Produce a design that makes the caller, data shape, ownership, failure behavior, and verification clear before implementation commits to them.

## Ground

Inspect the affected system. Use `how` when the runtime path or current ownership is unclear. Use `why` only when recorded rationale may constrain the new design.

State the goal, hard constraints, compatibility requirements, and success criteria. Preserve the existing design system and repository conventions unless the request changes them.

## Design

Write the caller's usage first. Derive the important types, function signatures, state transitions, and module ownership from that usage. Name where validation and errors live. Keep the public interface no larger than the caller needs.

Start with one coherent design. Use `arena` only when the user requests competing candidates. If the decision is expensive to reverse and no precedent distinguishes several credible designs, explain the tradeoff before incurring a multi-agent bakeoff.

Screen the result against [references/design-red-flags.md](references/design-red-flags.md). Revise shallow pass-through layers, leaked representations, lifecycle ordering disguised as ownership, and interfaces that expose internal coordination.

## Continue or stop

If the request asks only for a design, return the design and stop. If it asks for implementation, proceed without a checkpoint unless the user requested one or a missing product choice would materially change the result.

During implementation, revisit the design when repeated workarounds, type escape hatches, or the same unplanned dependency appear in more than one place. A single difficult edge case is not enough to restart the design.

Return the caller usage, type and state sketch, module ownership, tradeoffs, failure behavior, validation plan, and any open choice that requires the user.
