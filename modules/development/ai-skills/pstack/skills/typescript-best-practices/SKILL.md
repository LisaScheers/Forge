---
name: typescript-best-practices
description: Use when implementing or reviewing TypeScript types, public APIs, or untrusted-data boundaries, or when answering a TypeScript type-design question. Do not use for incidental file reads.
---

# TypeScript best practices

Apply the **type-system-discipline** principle skill first.

| Rule | Summary |
|------|---------|
| Discriminated unions | Model variants with a `kind` literal discriminant so impossible states can't be represented. No optional-field bags. |
| Branded types | Distinguish primitives when mixing them up creates a real invalid state. Follow the repository's branding convention and validate at creation. |
| Constructive modeling | Use tuples and discriminated unions to exclude invalid shapes. A start plus duration makes range calculation explicit; numeric constraints still need validation. |
| Simplest total type | Keep `T[]` while every operation on it stays total. Strengthen to `NonEmpty<T>` only where the loose type forces `!`, a cast, or a "should never happen" throw. |
| `unknown` over `any` | External data is `unknown`. |
| Schemas before guards | Before hand-writing a property-by-property type guard, use the repository's runtime schema library and infer the type from the schema, such as `z.infer`. |
| Type assertions | Prefer inference and narrowing. Use a small assertion only for an established invariant TypeScript cannot express; `as const` is also valid. Assertions do not validate runtime data. Avoid wrappers that only cast. |
| Narrowing hierarchy | Discriminant switch > `in` operator > `typeof`/`instanceof` > user-defined type guard > `as`. |
| Type guards | Must verify the claim. A lying guard is worse than `as` because the bug hides behind a name that says it's safe. Name them `isX` or `hasX`. |
| Exhaustiveness | Inline `const _exhaustive: never = x;` in default arms so the compiler errors when a new variant is added. |
| `satisfies` | Check assignability at compile time while retaining useful inferred details. Contextual typing still affects inference; this is not runtime validation. |
| Boundary validation | Parse external representations into domain types at entry. Avoid repeated shape checks; retain domain preconditions and runtime invariant checks. See the **boundary-discipline** principle skill. |
| Schema-derived types | Reach for `Pick`/`Omit`/`Parameters`/`ReturnType`/`Awaited`/`typeof` before declaring a new interface. |
| Object args | Prefer named options for several easily confused inputs. Preserve clear positional APIs and existing conventions; consider allocation cost on hot paths. |
| Real tests | Don't mock what you can run. Prefer the framework's real test primitives with leak/disposable checks, and verify UI in a running build. Mock only what you can't run locally. |
| Structured telemetry | Prefer structured logger diagnostics with enough context to debug from an id. No `console.log` in shipped code. |

Examples: `references/patterns.md`.
