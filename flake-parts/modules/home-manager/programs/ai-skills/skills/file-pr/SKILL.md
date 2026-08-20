---
name: file-pr
description: File a concise pull request. Use when the user asks to file, open, or create a PR.
---

# File PR

Before filing, check whether the branch already has a pull request. Review the local diff against the base branch and make sure every included change serves the user's original goal.

Pull request titles often become commit messages. Read the repository's title conventions, recent merged pull requests, and Git history before choosing one. Prefer a short, human-readable title that communicates why the change matters.

Bad:

> `perf(server): alter websocket compression settings`

Better:

> `perf(server): shrink websocket frames with compression`

Begin the description with the problem from the user's point of view. Follow it with a brief explanation of the solution. Do not lead with a long inventory of files, functions, or implementation details.

Bad:

> Changed settings resolution in four entry points and refactored the shared helper.

Better:

> New threads ignored the saved worktree preference. They now use that preference consistently.

End with a short attribution in this shape:

> Assisted by an LLM using `[model]` in `[harness]`.

Rebase onto the latest base branch, then open a ready-for-review pull request rather than a draft so the review bots run. If the user also asked you to watch it, continue with `babysit-pr`.
