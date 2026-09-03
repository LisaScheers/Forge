# Plan

Produce an implementation plan grounded in the repository and the user's constraints. The plan is the deliverable. Do not implement.

## Triage

Skip formal planning when the change is small and the approach is obvious unless the user explicitly asked for a plan. Say that the task can be handled directly and stop.

Use a plan when work has dependent stages, consequential architecture, competing approaches, unclear scope, or a user request for one.

## Ground the plan

Inspect the relevant code, conventions, entry points, dependency boundaries, and existing verification. Explore directly by default. Delegate only independent subsystems when the extra coverage justifies coordination; give each explorer a distinct scope and require file pointers and concrete findings.

Read a `principle-*` skill only when it resolves a real planning decision. Use `skill-creator` for a phase that creates or changes a skill.

State the goal, scope, exclusions, constraints, and definition of done. Ask only when a missing choice materially changes the plan. Give concrete options when asking.

## Write the plan

Use the location and format the user requested. Otherwise prefer one Markdown file. Split into an overview and phase files only when that makes a long plan easier to execute or review.

Start with the outcome. Then include:

- the current behavior or problem;
- in-scope and out-of-scope work;
- constraints and repository patterns to preserve;
- the chosen approach and material alternatives, when alternatives are credible;
- ordered implementation phases;
- verification and remaining decisions.

Size phases around coherent outcomes and dependency order, not file counts. Each phase should state:

- its goal;
- the important files or modules involved;
- the data shape, interface, or state transition when relevant;
- the behavior it preserves or introduces;
- the narrowest static and runtime evidence that will prove it complete.

Prefer phases that can be checked independently, but do not manufacture tiny phases or require every intermediate state to be shippable. Put shared types or infrastructure first only when later work actually depends on them.

For a bug, plan to reproduce with the strongest available artifact, fix the supported cause, and verify on the matching surface when the environment permits. For a refactor, identify the behavior contract and an appropriate equivalence check. For user-facing work, include a real surface check when tools and environment permit it.

Name a supporting skill only when the implementer should actually invoke it. Do not enumerate the entire skill chain. Include `show-me-your-work`, `interrogate`, or multi-agent workflows only when the task's size or risk earns them. Include PR creation or monitoring only when the user requested that delivery work.

## Hand back

Summarize the phases, scope boundaries, verification, and any decision the user must make. Stop. The user decides when implementation starts.
