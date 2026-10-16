---
name: babysit-pr
description: Use when the user asks to monitor, watch, or babysit a pull request through review and CI.
---

# Babysit PR

The repositories we work in may have AI review bots. They are useful, but they are not always correct.

Use a monitoring tool when the harness provides one. Otherwise, poll the pull request for new comments and check results.

Only act on checks and comments newer than the latest push. Confirm every bot finding in the source before changing code. Fix genuine issues and CI failures, identify infrastructure flakes correctly, and give a written reason when dismissing a false positive.

Watch the base branch and rebase when the pull request becomes stale. If another pull request overlaps enough to make this one obsolete, stop, tell the user, and ask before closing unless closure was already authorized.

When replying on Lisa's behalf, use this format:

```md
[MODEL-SLUG] ASSISTED BY AN LLM, RESPONDING ON BEHALF OF LISA
-----
[reply]
```

Screenshots and recordings can help explain visual findings. Use the `file-upload` skill when it is available.

Do not allow review feedback to expand the pull request beyond the user's original goal. Address real shortcomings without absorbing unrelated work.

If there is no new state, stay quiet. Stop when the latest commit is green and review feedback is settled. Merge only when the user's requested disposition says to merge; otherwise report the result and ask what to do next.
