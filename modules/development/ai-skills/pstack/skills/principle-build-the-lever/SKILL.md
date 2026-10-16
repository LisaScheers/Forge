---
name: principle-build-the-lever
description: "Use when work is repetitive, error-prone, reusable, or otherwise hard to verify. Build the smallest script, codemod, generator, or check that materially improves execution or proof."
---

# Build the Lever

When repeatability or proof matters, build the smallest tool that does or verifies the work.

**Why:** Two payoffs. Throughput: a codemod, generator, or script does the work the same way every time and reruns for free. Confidence: the tool is one artifact a reviewer can read and rerun to check the work. Hand-done changes can only be re-verified by redoing them. A deterministic script turns "trust me" into "run this".

**Pattern:** Build a lever when it reduces error, makes review reproducible, or will be reused. Skip it when the script would cost more and reveal less than a few obvious edits.

- Do the first unit by hand to learn the recipe, then build the tool. Prove it by rerunning it on that unit and diffing against your hand-done version. Make the lever safe to rerun. A reviewer will.
- Codemod or script for edits, generator for repetitive files, a dump-to-sqlite query for analysis, a rerunnable check for verification.
- A deterministic lever beats fan-out. If the tool can process every unit in one pass, run it yourself; don't fan out delegates to hand-apply what a script can do.
- When you fan work out to subagents, write the lever as a skill they all read: the recipe, the verification contract, and the do-not-touch fences in one artifact, so every delegate inherits the same hardened version instead of re-explaining it per prompt and watching each one drift. Keep it outside the delegates' write scope so they can't quietly edit the contract.
- Direct work is better for a few obvious edits when a tool would cost more and prove less.
- Commit the lever only when the work or verification needs to outlive the session.

**Balance:** A one-off can still earn a lever when the tool is the cheapest reliable proof. Per the [Laziness Protocol](../principle-laziness-protocol/SKILL.md), build the smallest tool that does or proves the job, never a framework.

Distinct from [Encode Lessons in Structure](../principle-encode-lessons-in-structure/SKILL.md), which makes a recurring instruction a durable guardrail. This is throughput and reviewability on the work in front of you. For scripting the verification itself, see [Prove It Works](../principle-prove-it-works/SKILL.md).
