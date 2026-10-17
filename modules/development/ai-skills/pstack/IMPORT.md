# pstack import

Upstream revision: `09d06eb4b97a1020ab31e84030e38baf1099c7dc` (2026-10-17).

The initial import retained upstream content except for Codex compatibility changes: skill locations, skill authoring, questions, transcript access, subagent calls, model selection, and explicit invocation metadata. The Comment Sicko prompt and the upstream principles index are bundled with their calling skills. MIT license retained.

Local revisions authorized after review:

- `architect`: respect design-only requests and existing implementation authorization; keep candidate runners in their assigned phase and describe model diversity accurately.
- `reflect`: honor existing edit authorization, keep review-only requests as proposals, and require authorization for tracker writes; use supported skill-creator workflows and metadata.
- `typescript-best-practices`: narrow its trigger, correct assertions and `satisfies` guidance, make branding and object arguments conditional, and fix tuple and range examples. Align its companion `principle-type-system-discipline` branding guidance.
- `principle-boundary-discipline`: avoid duplicate representation checks while preserving runtime domain invariants; synchronize the architect and TypeScript references.
- `benchmark-checklist`: remove references to omitted playbooks and include the macOS core-count command.
- `automate-me`: replace the unavailable description-optimization workflow with the current skill-creator guidance.
- `ketchup`: replace the native `/visualize` dependency with the local `visualize` skill, Mermaid, or locally rendered charts.

`visualize` is not an importable skill in the public source at the pinned revision or at `101b274dd991f694e1f7024be2157e5f3adf07de` (checked 2026-10-17). Pstack's `ketchup` references match the native inline chart and diagram feature documented in [Cursor's release notes](https://prod.cursor.com/docs/release-notes) and [Cursor's announcement](https://www.linkedin.com/posts/cursorai_cursor-can-now-build-charts-and-diagrams-activity-7510777828880228353-umn1). A separate, locally authored `visualize` skill now provides HTML Canvas/WebGL artifacts using pinned Apache ECharts, Three.js, and 3Dmol.js runtimes, plus native Canvas for custom models and simulations. It lives in `../skills/visualize`, outside this upstream import, and is packaged through Forge's bundled-skills option. `ketchup` retains alternatives when that skill is disabled.

Skipped skills (no suitable direct Codex equivalent):

- `setup-pstack`: Per-role model rules and model-family defaults have no direct Codex configuration equivalent.
- `make-bot-ui`: Requires Grok Bot webhook routines and secret-request cards unavailable in Codex.
- `poteto-mode`: Requires cloud subagents, custom agent types, and external control/deslop skills without direct Codex equivalents.
- `swarm`: Requires cloud workers and cloud_base_branch; Codex collaboration agents share the local workspace.
- `poteto-help`: Documents the omitted setup, mode, cloud workflows, and harness UI.
