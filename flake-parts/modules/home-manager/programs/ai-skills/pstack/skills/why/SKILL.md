---
name: why
description: Use only when the user explicitly asks why a code or product decision was made, requests decision history or rejected alternatives, or wants evidence across historical records. Use how for runtime behavior.
---

# Why

Find the evidence that explains why a design or behavior exists. Separate recorded intent from inference. This is a read-only investigation unless the user separately asks for changes.

## Start with the code anchor

Identify the relevant files, symbols, and lines. Inspect the local history with the smallest useful git query. Read linked pull requests when their discussion may contain the reason.

Code proves current behavior, not historical intent. Treat a reason inferred from code as an inference unless a commit, review, ticket, document, chat message, incident, metric, or comment states it.

## Retrieval budget

Start with source control and the most likely first-party source. Answer when those results support the core request.

Search another source only when:

- a required owner, date, decision, constraint, or rejected alternative is missing;
- the first result points to another record;
- sources conflict;
- the user asks for broad or exhaustive history.

Potential sources include issue trackers, long-form documents, team chat, infrastructure observability, error tracking, and product analytics. Do not query every available category by default. An empty result means only that the search found no supporting record.

Parallelize independent reads when several sources are required. Use subagents only when the user requested parallel research or the investigation is broad enough that independent source ownership improves coverage. Inherit the parent model unless repository configuration supplies a supported model and reasoning effort as separate settings.

For an exhaustive decision or incident review, read [references/epistemics.md](references/epistemics.md) and the relevant source playbooks under `references/sources/`. Do not load unrelated source playbooks.

## Evidence rules

- Cite the record that supports each claim about intent.
- Label inference separately from direct evidence.
- Surface contradictions instead of choosing the tidier story.
- State which required evidence remains missing.
- Quote only the few words needed to establish the point.

## Stop

Stop when the core question has enough direct evidence, or when the remaining required fact cannot be reached with the available sources. Do not search again only to improve phrasing or add background.

Return a direct answer, followed by the supporting evidence, material inference, conflicts or gaps, and the sources consulted. When the investigation informs a proposed change, end with the constraints that the change should preserve.
