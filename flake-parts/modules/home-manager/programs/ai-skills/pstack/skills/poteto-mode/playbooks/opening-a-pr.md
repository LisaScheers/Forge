# Opening a PR

Use only when the user asks to open a pull request.

1. Read and follow the repository's PR instructions.
2. Use the `file-pr` skill. It owns branch preparation, title and description conventions, checks, and creation of the PR.
3. Keep the diff focused. Apply `unslop` to PR prose and remove unrelated edits. Use additional cleanup or review skills only when installed and justified by the change.
4. Return the PR URL and the checks run.
5. Use `babysit-pr` only when the user also asks to monitor or babysit the PR. Do not merge unless the user gives that authority.

A delegated PR task returns the URL to the parent and does not expand into monitoring unless that was part of its scope.
