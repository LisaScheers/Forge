# TypeScript patterns

Code examples for each rule in `SKILL.md`. The underlying principles are language-agnostic. See the **type-system-discipline** and **boundary-discipline** principle skills.

## Branded types

Brand primitives when mistaken interchangeability creates a real invalid state. Validate at creation; downstream code can then rely on the established invariant.

```ts
type AgentId = string & { readonly __brand: "AgentId" };

function parseAgentId(input: string): AgentId {
  if (!isUUID(input)) throw new Error(`Invalid agent id: ${input}`);
  return input as AgentId;
}

function focusAgent(id: AgentId): void {
  /* input is trusted */
}
```

The brand above is an example. Follow the repository's existing convention, including schema-library brands or unique symbols, rather than adding a competing one.

## Discriminated unions

Model variants with a literal discriminant. Every variant shares the field name and each variant's value is unique, so impossible combos can't be represented.

```ts
// Don't. Boolean + optionals lets contradictory states exist.
type DiffState = { loading: boolean; diff?: GitDiff; error?: string };

// Do. Only valid states exist.
type DiffState =
  | { kind: "loading" }
  | { kind: "ready"; diff: GitDiff }
  | { kind: "error"; error: string };
```

Pick one discriminant name (`kind`, `type`, `tag`) and stick to it.

## Constructive modeling

Use structure to exclude invalid shapes where TypeScript can express the constraint. Validate facts the type cannot express at creation, and preserve the invariant afterward.

Non-empty, via a variadic tuple:

```ts
type NonEmpty<T> = readonly [T, ...T[]];

// Don't: T[] plus a length check every caller must repeat
function firstEntry(entries: string[]): string {
  if (entries.length === 0) throw new Error("no entries");
  return entries[0]!;
}

// Do: the first element exists, without an assertion
function firstEntry(entries: NonEmpty<string>): string {
  return entries[0];
}
```

Where a plain `T[]` arrives, narrow once with a guard. The fact then travels in the type:

```ts
const isNonEmpty = <T>(arr: readonly T[]): arr is NonEmpty<T> => arr.length > 0;
```

Even length, as pairs:

```ts
type Pairs<T> = readonly (readonly [T, T])[];
```

A time range, as start plus duration:

```ts
// Don't: a comment holds the invariant
type TimeRange = { start: Date; end: Date }; // start <= end

// Makes duration explicit; validate it at creation and derive end when needed
type TimeRange = { start: Date; durationMs: number };
```

`number` still permits negative, infinite, and NaN durations; this shape alone does not enforce a valid range. Validate a valid start and finite, nonnegative duration at creation. Use the repository's existing validated duration type when there is one; add branding only when it prevents a real mix-up. Keep tuple values from being emptied through mutable aliases; readonly prevents mutation through that reference, not through other aliases.

## Simplest total type

Don't strengthen everything. Keep `T[]` when every operation on it is total:

```ts
const sum = (xs: number[]) => xs.reduce((a, b) => a + b, 0); // [] is 0, fine
```

Strengthen when the loose type forces a lie at a use site. The tells are `!`, `arr[0] as T`, and a "should never happen" throw:

```ts
// Don't: partiality smuggled past the compiler
function newestSession(sessions: Session[]): Session {
  return sessions.at(0)!;
}

// Do: strengthen the input; the assertion disappears
function newestSession(sessions: NonEmpty<Session>): Session {
  return sessions[0];
}
```

Weakening the result to `Session | undefined` is the other total signature.

## `unknown` over `any`

External data is always `unknown`. Narrow before use.

```ts
// Don't
function handle(input: any) {
  return input.foo.bar;
}

// Do
function handle(input: unknown) {
  if (typeof input === "object" && input !== null && "foo" in input) {
    // narrowed; compiler verifies access
  }
}
```

External sources include RPC payloads, `JSON.parse`, `postMessage`, IPC, file contents, environment variables, database results.

## Schemas before hand-rolled guards

Before writing a property-by-property type guard for external data, look for the repository's runtime schema library and existing schemas. Let one schema own validation and derive the TypeScript type from it. Do not maintain a schema, a duplicate interface, and a guard that can drift apart.

```ts
import { z } from "zod";

const UserSchema = z.object({
  id: z.string().uuid(),
  role: z.enum(["admin", "member"]),
});

type User = z.infer<typeof UserSchema>;

function parseUser(input: unknown): User {
  return UserSchema.parse(input);
}
```

Use `safeParse` when failure is an expected branch. Use the equivalent inference helper when the repository uses another schema library. Do not add a new schema dependency for one guard. This rule prefers the schema system the codebase already trusts.

## Type assertions

Prefer inference and narrowing. An assertion changes what the compiler accepts; it does not check a value at runtime. Use it only when an invariant is established but TypeScript cannot express the proof, as with the validated brand above. `as const` is useful for literal inference and readonly types; it does not freeze runtime objects.

```ts
import { z } from "zod";

// Don't
const user = data as User;

// Don't
function isUser(data: unknown): data is User {
  return typeof data === "object" && data !== null && "id" in data;
}

// Do
const userSchema = z.object({ id: z.string(), name: z.string() });
type User = z.infer<typeof userSchema>;

function parseUser(data: unknown): User {
  return userSchema.parse(data);
}
```

When the type comes first, annotate the validator with the type it proves. The compiler then rejects a validator that proves less than the type. Remove `name` from the object below and the assignment fails to compile.

```ts
type User = { id: string; name: string };

const userSchema: z.ZodType<User> = z.object({ id: z.string(), name: z.string() });
```

When refactoring an `as` out of existing code, identify why TypeScript can't infer:

- Missing discriminant: add one, switch to a discriminated union.
- Overly wide source type (e.g. `Record<string, unknown>`): narrow it.
- Untyped boundary: parse with the schema that owns the shape. Add a schema only where none exists.
- Established invariant the compiler cannot express: keep a small, justified assertion at that point. Do not add wrappers that exist only to cast, or use `satisfies` as a substitute for a missing runtime check.

## Narrowing hierarchy

From best to last-resort:

1. **Discriminated union switch / if.** Compiler narrows automatically.
2. **`in` operator.** `"key" in obj` narrows to variants containing that key.
3. **`typeof` / `instanceof`.** For primitives and class instances.
4. **User-defined type guard.** When the above aren't enough.
5. **Type assertion.** Only for an established invariant the compiler cannot express; never as a replacement for external-data validation.

```ts
function area(s: Shape): number {
  if ("radius" in s) return Math.PI * s.radius ** 2; // narrowed to circle
  return s.width * s.height; // narrowed to rect
}
```

## Type guards

A guard must actually verify the claim. A lying guard is worse than `as`.

```ts
function isCircle(s: Shape): s is Shape & { kind: "circle" } {
  return s.kind === "circle";
}
```

Prefer discriminant narrowing when possible.

## Exhaustiveness

In default arms, assign the discriminant to a `never`-typed local.

```ts
// Value-returning switch
function area(s: Shape): number {
  switch (s.kind) {
    case "circle":
      return Math.PI * s.radius ** 2;
    case "rect":
      return s.width * s.height;
    default: {
      const _exhaustive: never = s;
      return _exhaustive;
    }
  }
}

// Void switch
function handle(s: Shape): void {
  switch (s.kind) {
    case "circle":
      drawCircle(s);
      break;
    case "rect":
      drawRect(s);
      break;
    default: {
      const _exhaustive: never = s;
      void _exhaustive;
    }
  }
}
```

Return-style in value-returning switches, void-style in statement switches.

## `satisfies`

`satisfies` checks assignability at compile time without replacing the expression's type with the target type. It retains useful inferred details, but contextual typing can still affect inference. It performs no runtime validation.

```ts
type Config = { theme: "dark" | "light"; cols: number };

// Don't. Widens, loses literal types.
const config = { theme: "dark", cols: 3 } as Config;

// Do. Checks assignability; theme retains its literal type here.
const config = { theme: "dark", cols: 3 } satisfies Config;
// config.theme is "dark" (literal), not string
// config.cols is number, not the literal 3
```

## Boundary validation

Parse external representations at entry and avoid duplicate shape validation inside. Keep domain preconditions and invariant checks for runtime state that types cannot establish. See the **boundary-discipline** principle skill.

- **Wire formats** (proto, JSON-RPC): parse with `ignoreUnknownFields` so forward-compatible changes don't break old clients.
- **Persisted JSON:** versioned blob with a try/catch around the parse.
- **Don't re-validate** deep in call chains.

## Schema-derived types

When a `.proto`, OpenAPI spec, GraphQL schema, or database migration already defines a shape, derive from the generated types instead of duplicating them.

```ts
// Don't. Duplicate shape, drifts when the schema changes.
type CheckSummary = {
  totalCount: number;
  checks: { name: string; status: string }[];
};
function renderChecks(s: CheckSummary) {
  /* ... */
}

// Do. Derive from the generated schema type.
import type { ChecksMessage } from "<generated module>";
function renderChecks(s: Pick<ChecksMessage, "totalCount" | "checks">) {
  /* ... */
}
```

Reach for `Pick`, `Omit`, `Parameters`, `ReturnType`, `Awaited`, `typeof` before writing a new interface.

## Object args

Prefer named options when inputs are easily confused. Clear positional APIs remain useful; do not rewrite existing signatures solely to force this style.

```ts
// Two strings can be accidentally swapped and still compile.
moveFile(source, destination);

// Named inputs make the intent visible.
moveFile({ source, destination });

// A familiar positional API is already clear.
parseInt(text, 10);
```

Skip on hot paths: per-frame render, tokenizers, parsers, anything in a tight loop where the allocation cost matters.
