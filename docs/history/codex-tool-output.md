# Codex tool output in telemetry, 2026-11-23

A dated record. [AI usage](../ai-usage.md#usage-telemetry) describes the current
state.

Codex's `codex.tool_result` events kept up to 2,048 bytes of each tool result
until `tool_result.max_bytes = 0` reached Vega at 07:43 CET on 2026-11-23; the
last event with output arrived at 07:30. Events received before then can hold
command output, so treat them like captures. They can be removed on Nook with:

```sql
ALTER TABLE otel.otel_logs DELETE
WHERE ServiceName = 'codex-app-server' AND Timestamp < '<deployment time>'
```

That delete has not been run.
