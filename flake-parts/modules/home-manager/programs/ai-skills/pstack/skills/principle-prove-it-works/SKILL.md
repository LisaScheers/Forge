---
name: principle-prove-it-works
description: "Use when an implementation or other checkable artifact needs direct verification before completion is reported."
---

# Prove It Works

Verify a checkable task output against the real thing. Use the narrowest direct check that exercises the requested result. Broaden to integration, end-to-end, or visual checks when a boundary changed or failure would be costly.

**Why:** Unverified work has unknown correctness. Indirect verification (file mtimes, output freshness, agent self-reports, cached screenshots) feels cheaper than direct observation. Acting on a wrong inference costs far more than checking the source.

**Pattern:** After completing any task, ask: "how do I prove this actually works?"

Check the real thing, not a proxy:
- Check process liveness directly, not indirectly through derived state
- Read the actual value, not a cached or derived representation
- When verification fails, suspect the observation method before suspecting the system

Code and features:
1. Run the focused test or command that exercises the changed behavior.
2. Add type, lint, or build checks when they cover a contract the change could break.
3. Exercise the real feature path when unit-level checks cannot prove the user-visible result.
4. Test the full communication path when an integration boundary changed.

Delegation: trust artifacts, not self-reports.
When verifying delegated work, inspect the actual output artifact (git diff, file contents, runtime behavior), not the delegate's summary. Agents report what they intended, not always what happened.

## Script the check when it earns its place

Use a deterministic script when the comparison is repetitive, subtle, or important enough that a reviewer should rerun it. Reuse an existing check when it already proves the point. Do not create a script for a few obvious observations that are cheaper to inspect directly.

Keep the artifact visible for the human. Commit it only for large or complex work where the trail has to be auditable later, like a big port or migration (the **show-me-your-work** skill). Most work just needs it visible, not committed.
