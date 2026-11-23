# shellcheck shell=bash
# Claude Code status line: model and effort, context used, and plan limits.
# Reads Claude's status JSON on stdin, for example
#   Opus 5.5 high · context 23% · 5h 41% · week 12%
jq -r '[
  ([.model.display_name, .effort.level] | map(select(. != null)) | join(" ")),
  (.context_window.used_percentage | if . == null then empty else "context \(round)%" end),
  (.rate_limits.five_hour.used_percentage | if . == null then empty else "5h \(round)%" end),
  (.rate_limits.seven_day.used_percentage | if . == null then empty else "week \(round)%" end)
] | map(select(. != "")) | join(" · ")'
