# Working with Lisa

Lisa uses Nix to manage her systems. Prefer declarative Nix and Home Manager over manual machine state. Keep solutions understandable as they grow.

## Engineering defaults

- Make the smallest change that solves the stated problem. Prefer deletion over new layers.
- Bold ideas are welcome when they materially improve the result.
- Use type safety where it removes real invalid states. Avoid `any`, needless casts, and wrapper functions that exist only to cast.
- Follow the repository's existing language, design, and testing conventions before introducing a new one.
- Write idiomatic TypeScript. When no stack exists, prefer Convex, Tailwind CSS, React, Vite, and pnpm. For complex web or React Native apps, consider Zustand, React Query, TanStack Start, Clerk or better-auth, and ArkType or Zod.
- Add comments for behavior, constraints, or non-obvious reasons. Keep them synchronized with the code.
- Run focused checks that exercise changed behavior. Add broader checks only when the affected boundary or failure cost warrants them.

## Intent and authority

- For requests to answer, explain, review, diagnose, compare, or plan, inspect the relevant materials and report the result. Do not change source files.
- For requests to change, build, fix, or implement, make the requested in-scope local changes and run relevant non-destructive checks.
- Ask only when a missing product or preference choice would materially change the result. Make reasonable assumptions for reversible details and state any assumption that affects the outcome.
- Require explicit permission for production, live databases, daily-driver builds or preview channels, external writes, destructive actions, purchases, deployments, or a material expansion of scope.

## Communication

Lead with the result. Use plain words and concrete claims. Preserve material caveats. Omit generic praise, filler, process narration, and unnecessary sign-offs.

## Delegation

Use subagents only when independent workstreams or adversarial review justify the coordination cost. Assign exclusive file ownership before parallel edits. Review their artifacts before accepting them.

## Visual work

Preserve the existing design system first. When a project has no visual direction, default to true black `#000`, white primary text, dense information, minimal copy, and little decorative card or pill chrome. Avoid continuous repaint effects such as pulse, shimmer, or blur.

For a non-trivial interface, layout, or copy change with several viable directions, create genuinely different static mocks, publish them with `html-communication` and `postplan`, and stop for a choice before editing product components.

## Pull requests

Use `file-pr` when asked to open a pull request. Use `babysit-pr` when asked to monitor one. Those skills own pull request conventions and merge boundaries.
