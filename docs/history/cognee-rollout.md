# Cognee rollout, 2026-10

A dated record. [Cognee](../cognee.md) describes the current state.

On 2026-10-03, GLM 5.3 Flash through OpenRouter was deployed and verified
after Lisa approved replacing GPT-6 Luna. JSON-schema inference and a full MCP
write, graph build and retrieval passed in the `forge_operations` dataset.
Existing `life` memory remains readable. Lisa subsequently chose local searchable
email indexing with a maximum $10 OpenRouter import budget. The paid bulk run was
stopped, and cleaned emails use a deterministic pipeline with local embeddings.
Lisa's Vega Codex and Nook's `codex` account use Authentik. OpenRouter usage is
billed to Lisa's existing OpenRouter account.
Graph storage was recovered and the viewer and MCP recall verified again on
2026-10-03; the deployed graph library and buffer limits are described in
[Cognee](../cognee.md#graph-storage-recovery).

Verified on 2026-10-02:

- Nook/Atlas system and Vega Home Manager evaluations; packaged login helper;
  18 adapter tests and FastMCP 3.4.7 OAuth/HTTPS origin compatibility checks.
- Persistent data, model cache and Podman storage reside on the projects NVMe.
  All three application listeners bind only to `127.0.0.1`.
- Trusted Let's Encrypt TLS; public health returns 200; anonymous REST and MCP
  return 401; MCP advertises OAuth discovery; public registration returns 403.
- Authentik provider and administrator-group binding are present. Lisa completed
  browser authorization; both Vega and Nook Codex accounts discovered the four
  tools of that release (`code_search` arrived later).
  A separate non-administrator login was not exercised.
- GPT-6 Luna structured inference and Cognee graph extraction completed through
  the subscription adapter. Synthetic text ingestion completed in about 18 seconds.
- REST graph recall returned the synthetic fact. After API/MCP restart, a fresh
  Codex chat recalled the same fact through its authenticated MCP connection.
- Authenticated server-path ingestion returns 415; outbound URL ingestion returns
  403; uploaded text succeeds. The disposable verification dataset was removed.
