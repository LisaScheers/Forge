# AI gateway cutover, 2026-11-05

A dated record. [AI usage](../ai-usage.md) describes the current state.

Build Nook and its deploy-rs checks before activation. Lisa approved the scoped
`nixpkgs.config.problems.handlers."gtk+".broken = "warn"` exception on Nook on
2026-11-05, preserving the existing Firestorm dependency at this Nixpkgs lock.
The host build, deployment schema, and activation checks passed before cutover.
That exception was removed on 2026-11-20 once Nook evaluated without it. At
cutover, the `dendritic` check also failed on the visualize skill's recipe,
since moved to `packages/visualize-skill/`.

Vega disables `targets.darwin.copyApps.enable` and enables
`targets.darwin.linkApps.enable` at Lisa's request, following the
[upstream workaround](https://github.com/nix-community/home-manager/issues/8336).
The App Management preflight repeatedly reset consent, and macOS also rejected
app copying. Home Manager now manages application symlinks and completed two
consecutive activations successfully. The final system-generation switch was
also verified on 2026-11-05. The former copied-app directory is preserved under
`~/.local/state/forge-home-manager/apps-backup-20261105T142541/`.
Existing conflicting GPG backups and the local Aurora skill symlink were preserved under
`~/.local/state/forge-ai-proxy/activation-backup-20261105T140308`.

For subsequent changes, activate Nook first. Verify `cli-proxy-api-plus`,
`clickhouse`, `ai-usage-schema`, and the `ai-usage-ingest.timer`, trusted TLS,
rejection of missing API keys, and a real request's transcript and usage in
ClickHouse before switching clients. Update Vega's system configuration to
install its agenix key and host record. Restart Antigravity after changing provider
configuration; it and Cognee fail when the gateway is unavailable rather than
falling back to a direct route.

Codex, T3's Codex driver and Nook's `codex` account no longer use a gateway
provider: since the native-capture change they select Codex's built-in `openai`
provider (`model_provider = "openai"`). Cognee uses its existing OpenRouter
model through the gateway, with a private generated client environment file
written by `ai-proxy-cognee-env` ([Cognee](../cognee.md#models)).

Antigravity CLI uses [Gemini API mode and a custom endpoint](https://antigravity.google/docs/install?tab=cli).
Its wrapper reads the shared key at runtime, including when launched outside an
interactive shell. The live gateway catalog has replaced Gemini 3.7 Flash High
with `gemini-3.8-flash-high`. The client selects `Gemini 3.8 Flash (High)` by its
display name; Gemini API mode sends `gemini-3.8-flash`, which the gateway aliases
to that subscription model while retaining the original ID. Its subscription
sign-in completed on Nook on 2026-11-05;
the resulting credential is encrypted with agenix for provisioning the service.

At the 2026-11-05 cutover, real Vega Codex and Antigravity CLI requests both
completed through the gateway; Codex has since left it. The Codex verification stored 14,964 total tokens, including 6,272 cached input
tokens. Antigravity's verification stored the full Gemini usage object and
request/response transcript.

Asterion is excluded from this cutover at Lisa's request. Its provider
configuration is prepared, but its runtime key must be provisioned if it is
included later. Its host key is not
yet a recipient of the shared agenix secret, so this change does not declare an
undecryptable system secret for it. Standalone Home Manager installations use
`~/.config/cli-proxy-api-plus/client-api-key`; integrated Vega/Nook configurations
read their agenix secret paths.
