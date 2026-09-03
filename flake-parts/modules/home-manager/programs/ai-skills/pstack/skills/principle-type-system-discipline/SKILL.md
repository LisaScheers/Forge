---
name: principle-type-system-discipline
description: "Use when designing types or reviewing a public signature in a statically typed language. Encode important invariants where the safety gain exceeds the added ceremony."
---

# Type System Discipline

Use the type checker to eliminate meaningful impossible states, mismatched values, and unhandled variants. Prefer types that make the common code total, but do not encode precision that adds ceremony without preventing a plausible mistake.

Applies to any typed language. Skills like `typescript-best-practices` ground it in specific syntax.

**The patterns:**

- **Make illegal states unrepresentable.** Model variants as sum types: discriminated unions in TypeScript, enums with payloads in Rust/Swift/Kotlin, sealed classes in Scala, ADTs in Haskell/OCaml. Don't model state as a bag of optional fields where contradictory combinations compile. A subtle anti-pattern worth naming: `{ completed: boolean; completedAt?: Date }` admits `completed: true; completedAt: undefined`, which is meaningless. Derive the boolean from a single source like `completedAt !== null`, or model the variants explicitly as `{ kind: 'open' } | { kind: 'done'; at: Date }`. If a bug forces the question "wait, can this combination actually happen?", the type is too loose.
- **Types are constructions, not restrictions.** Build the type up from the values you want instead of carving them out of a looser type with checks. The invariant that seems to need a refinement type is usually a construction away. A non-empty list is a head plus a rest, not a list with a length check. A valid time range is a start plus a duration, not two timestamps you must keep ordered. No representation is privileged. A list of pairs is an even-length list if you interpret it that way, so choose the shape that cannot build the illegal value and expose the interface callers need on top.
- **Brand semantic primitives when mixing is plausible.** `UserId` and `OrderId` may need distinct types when they cross the same APIs or accidental exchange would be costly. Keep plain primitives when the local context already makes the meaning unambiguous.
- **External data is untyped until parsed.** RPC payloads, JSON, IPC messages, CLI args, config files, environment variables, database rows. Have a parse function at every boundary that turns unstructured input into the typed model. See the **boundary-discipline** principle skill for where to put validation.
- **Keep assertions narrow and evidenced.** Prefer validation, narrowing, or a better model. Use a local assertion when runtime validation or an authoritative upstream contract proves a fact the type system cannot express. Do not let an assertion widen into unchecked data flow.
- **Exhaustive matching is the compiler's job.** When you match on a sum type, the compiler must fail compilation if a new variant is added without handling. Use the idiom your language provides: `never`-typed binding in TypeScript, unannotated `match` in Rust, `-Wincomplete-patterns` in Haskell, sealed-class match exhaustiveness in Kotlin.
- **Derive types from authoritative schemas.** When a protocol buffer, OpenAPI spec, GraphQL schema, database migration, or design-system token file defines a shape, derive from it instead of hand-rolling a parallel type. Manual duplication drifts. See the **encode-lessons-in-structure** principle skill.
- **Strengthen a type only where partiality appears.** A runtime assertion, null check, or "this should never happen" throw marks the place a type is too weak. Push that check up into the type. Then stop. The type system's job is to track the cases each use site must handle, not to describe the data as precisely as possible. Prefer total functions. `sum` of an empty list is 0, so it takes the plain list. `head` of an empty list has no answer, so it demands the non-empty one. Extra precision costs reuse and ceremony and buys no safety.

**The tests:**

- "Can I write a comment explaining when this combination of fields is valid?" If yes, the type is too loose. Split it into a sum type.
- "Could two values with the same representation be mixed in a plausible call path, and would that matter?" If yes, consider a distinct type.
- "What evidence supports this `any`, cast, or assertion?" Narrow or validate it when the evidence is absent.
- "If a new variant is added next month, will the compiler tell the next agent where to add a case?" If no, the match isn't exhaustive.
- "Is this type duplicating a shape another file owns?" Derive instead.
- "Am I strengthening this type to keep an operation total, or just to be more precise?" If nothing would otherwise panic, keep the plain type.
