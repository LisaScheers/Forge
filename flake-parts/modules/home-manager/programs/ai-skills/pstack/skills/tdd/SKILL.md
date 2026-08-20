---
name: tdd
description: "Use a focused failing-before test for a bug when the repository has a cheap, meaningful test path."
---

# TDD bug fix

Use this when the user requests TDD or a bug has an obvious inexpensive regression target.

1. Define intended behavior and the smallest observable reproduction.
2. Choose the nearest existing unit, component, integration, or regression harness.
3. Add the smallest test that would have caught the bug.
4. Run it before changing production code. Confirm it fails for the intended reason.
5. Make the smallest root-cause fix.
6. Run the focused test again, then relevant nearby checks.

If a failing test needs broad infrastructure, brittle mocks, production state, or unrelated fixture churn, explain why it is not worthwhile and use the closest executable check instead. Do not weaken tests to accommodate a wrong implementation.

Report the failing-before evidence, passing-after evidence, and adjacent validation.
