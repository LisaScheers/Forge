# A note from Lisa

I'm Lisa. You're my agent. We will be working together a lot, so I thought it would be worth introducing myself.

I use Nix to manage my systems and like building complex things in the simplest form that works. I especially value declarative, understandable setups whose complexity stays low as they grow.

I wanted to share some preferences so we can be better aligned while we work together. This is a rough draft. I will keep editing it as we learn what works.

## Coding preferences - general

- Keep things simple. Channel YAGNI energy unless I ask for a more elaborate solution.
- Type safety is useful. Take advantage of it.
- Bold ideas are welcome when they can meaningfully improve the work.
- Be careful with destructive actions I did not explicitly request.
- Tests are good when they are focused. Endless smoke tests and regression tests that only prove a deleted feature remains deleted are usually noise.
- Comments should clarify behavior or explain how something is used. Do not comment every line.
- Keep comments synchronized with the code when behavior changes.
- For system configuration, prefer declarative Nix and Home Manager over manual machine state.

## Coding preferences - TypeScript

- Avoid `any`. Prefer inference and types that naturally follow changes through the system.
- Write idiomatic TypeScript rather than code shaped like another language and translated into TypeScript syntax.
- Avoid tiny wrapper functions whose only purpose is a cast.
- When a project has not already chosen its stack, the draft defaults from the video are Convex, Tailwind CSS, React, Vite, and pnpm.
- For complex web or React Native applications, the draft choices are Zustand, React Query, TanStack Start, Clerk or better-auth, and ArkType or Zod.

## Questions are read-only

A question asks for an answer, not a file change. If I ask what you think, why something happens, whether something is possible, how difficult a change would be, or otherwise phrase the message as a question, answer it without editing files.

Even when the answer is obvious and the change looks trivial, answer first and offer to make the change. Wait for me to ask before editing.

## Match ceremony to the task

Do not assemble subagents or a multi-agent panel for work one agent can finish in a single pass. Delegation is useful for broad work or independent, adversarial review, not ordinary tasks.

When several agents do work in parallel, assign file ownership before they start so their edits do not collide.

## Visual and design work

For a non-trivial interface, layout, or copy change, do not begin by editing the real components. Make several genuinely different static mocks, publish them with the `html-communication` skill, share the URL, and stop so I can choose a direction before implementation.

The visual defaults copied from the video are a true-black `#000` dark background, white primary text, dense information, minimal copy, and little decorative card or pill chrome. Avoid pale subtitle rows above every section and avoid em dashes.

Avoid CSS animation that continuously repaints, such as constant pulsing, shimmer, blur, or loading effects. These can waste GPU resources on high-refresh displays.

## Blast radius

Never touch production, live databases, or a daily-driver build or preview channel unless I explicitly ask. If a task is close to one of those surfaces, say exactly what you are about to touch before touching it.

## Pull requests

- Follow the repository's title conventions. Keep the title short and easy to understand. Conventional-commit style is useful when the repository uses it, for example `fix(web): stop new threads from spiking CPU`.
- Start the description with a plain explanation of the problem, then briefly describe the solution.
- End the description with a short note naming the model and harness and saying the work was assisted by an LLM.
- Open a ready-for-review pull request rather than a draft so review bots run.
- Rebase onto the latest base branch before filing. Avoid spending a review cycle on stale conflicts.
- When asked to monitor or babysit a pull request, watch checks and comments for the latest push. Verify bot findings against the source, fix real issues, explain false positives, and distinguish code failures from infrastructure flakes.
- If nothing has changed, remain quiet rather than leaving filler comments.
- Follow the requested merge disposition. If I did not say whether to merge once green, report the result and ask.

Use `file-pr` when I ask to file, open, or create a pull request. Use `babysit-pr` when I ask to monitor, watch, or babysit one. Use `audit-codex-history` when I ask to review our history and improve this setup.
