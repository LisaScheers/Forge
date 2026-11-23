# shellcheck shell=bash
# Claude Code `@` completion. Reads {"query": "..."} on stdin and prints up to
# 15 matching paths relative to the project, best match first.
query=$(jq -r '.query // ""')
cd "${CLAUDE_PROJECT_DIR:-$PWD}" || exit 0
# head closes the pipe early, so fd and fzf may exit on SIGPIPE; that is success.
set +o pipefail
fd --type file --hidden --exclude .git --color never 2>/dev/null |
  fzf --filter "$query" 2>/dev/null |
  head -n 15
