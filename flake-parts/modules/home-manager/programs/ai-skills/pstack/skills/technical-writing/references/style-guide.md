# Technical writing style guide

## Match the document's job

A tutorial teaches through a sequence that produces visible results. Tell the reader what they will build and what they should observe after important steps.

A how-to assumes competence and gives the shortest safe route to a goal. Put conditions before the steps they govern and link to background instead of interrupting the procedure.

A reference mirrors the structure of the thing it documents. State supported values, defaults, limits, errors, and examples without persuasion.

An explanation answers a bounded why question. Include the context, constraints, alternatives, and tradeoffs needed to understand the design.

## Write sentences the reader can parse once

- Name the actor and action. Prefer “the compiler rejects the schema” to “the schema is rejected”.
- Write instructions as commands. Put a condition before the instruction it controls.
- Keep one instruction or one main thought in each sentence.
- Use the repository's real symbol, file, flag, and command names.
- Give one concept one name throughout the document.
- Keep pronouns close to an unambiguous noun.
- Put words such as “only” and “not” next to what they modify.
- Break up long noun strings and clauses that can group in more than one way.
- Use the short everyday word when it is equally precise.
- Keep necessary articles and connecting words. Do not trade clarity for a lower word count.

## Structure for use

- Use sentence-case headings that describe the section's point or task.
- Use numbered lists for sequences and bullets for unordered items.
- Introduce a list with a complete sentence and keep items grammatically parallel.
- Put the common path before exceptions.
- Use link text that names the destination.
- Mark code, symbols, and commands as code. Follow the repository's formatting conventions for snippets.
- Keep warnings beside the action they constrain.

## Review

Check that:

1. the title and opening tell the intended reader what this document helps them do or understand;
2. every instruction has enough context to run safely;
3. every fact, symbol, path, count, and output is true at the current revision;
4. conditions, defaults, errors, and failure behavior are stated where they affect a decision;
5. the document does not mix in background, completeness, or persuasion that its main job does not need;
6. the final prose is direct, concrete, and free of filler.
