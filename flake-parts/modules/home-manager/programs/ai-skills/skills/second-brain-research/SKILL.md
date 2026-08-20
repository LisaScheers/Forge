---
name: second-brain-research
description: "Use for every research or investigation task for Lisa. Check her Obsidian brain before external sources and automatically capture reusable findings as fleeting notes, never atomics."
---

# Use the second brain during research

Lisa's second brain is the Obsidian vault at `~/obsidian/brain`. Use it as the first source of context for research. This skill grants narrow standing permission to create fleeting notes during research. It does not grant permission to process those notes or turn them into atomic notes.

## Check local context first

Before the first web search or other external lookup:

1. Search the vault for the task's main terms, likely synonyms, and named entities. Search filenames and Markdown content. Ignore `.obsidian/`, `.agents/`, `meta/templates/`, and `attachments/`.
2. Read only the relevant notes. Follow useful wikilinks and named `up` links when they provide needed context.
3. Treat the notes as Lisa's prior context, not proof that a changing fact is still true. Use current or primary external sources when the task requires verification.
4. Keep private vault text out of external search queries and external tools unless Lisa explicitly asks to share it.

If the vault is absent, unreadable, or excluded by the active sandbox, continue the requested task. Report that local context and automatic capture were unavailable. Do not create another vault or weaken the sandbox.

## Capture reusable findings automatically

When research produces a finding, question, connection, or topic that may help Lisa later, create a fleeting note without interrupting the task to ask permission. This includes useful tangents that do not help the current task. Do not manufacture a note when the research yields only transient task output.

Use `$obsidian-capture-fleeting` when it is discoverable. Otherwise read and follow `~/obsidian/brain/.agents/skills/obsidian-capture-fleeting/SKILL.md`. Apply `$unslop` to agent-authored wording only. Preserve quotations, code, URLs, titles, filenames supplied by Lisa, and other source text exactly.

The capture must obey this note contract:

- Properties: use YAML frontmatter and list types defined by the fleeting-capture skill.
- Named links: preserve supported named links. A new unfiled capture normally has `up: []`. Never invent a relationship.
- Wikilinks: link only known vault notes or placeholders supplied by Lisa. Keep external sources as URLs.
- Tags: set `fleeting`. Do not add `atomic`, `literature`, `project`, or a new category.
- Descriptive filename: use a short content-based name. Do not use an ID, date stamp, or arbitrary numeric suffix.

Include enough exact provenance in the protected capture text to recover the source. Never invent a quote, author, title, URL, or claim. Search for an existing filename, matching capture, and source identity before writing. Reuse an existing match instead of creating a duplicate.

The only automatic vault write allowed by this skill is a root-level fleeting note. Do not execute a task mentioned in the capture.

## Delegate a useful tangent

When a topic may help later but does not help the current task, a research agent may delegate the fleeting-note write to one subagent if collaboration tools are available. Give that subagent only the exact finding, its provenance, the vault path, and the fleeting-capture contract. Assign it ownership of that one new root-level note so it cannot collide with other writers.

The subagent may check for a duplicate and write or report the fleeting note. It must not continue the tangent, spawn more agents, create an atomic note, process another note, or take an external action. If delegation is unavailable, the main agent captures the finding directly.

This delegation permission applies only to writing the bounded fleeting note. It does not expand the research task or authorize unrelated agents.

## Keep processing separate

Never invoke `obsidian-write-atomic`, `obsidian-process-fleeting`, or `obsidian-process-literature` under this skill. Never change a fleeting note into another category. Atomic writing happens later through Lisa's review and processing workflow.

At the end of the task, say which vault context informed the work and list any fleeting-note paths created or reused. Keep this to one short line when nothing needs explanation.

## Sources

- Lisa's direct instruction on 2026-08-20: agents check the second brain before web research, capture potentially reusable topics as fleeting notes, may delegate tangential captures, and do not create atomic notes.
- `~/obsidian/brain/.agents/skills/obsidian-capture-fleeting/SKILL.md`: fleeting-note location, schema, protected text, deduplication, conflict handling, and capture-before-action rules.
