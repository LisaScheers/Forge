---
name: principle-encode-lessons-in-structure
description: "Use when you catch yourself writing the same instruction a second time, or notice a recurring correction. Encode the rule as a lint, metadata flag, runtime check, or script instead of more text."
---

# Encode Lessons in Structure

Encode recurring fixes in mechanisms (tools, code, metadata, automation) instead of textual instructions. Every error, human correction, and unexpected outcome is a learning signal. Capture it, route it, and close the loop.

**Why:** Textual instructions are easy to miss. They require the reader to notice, remember, and comply. Structural mechanisms (lint rules, metadata flags, runtime checks, automation scripts) enforce the rule without cooperation.

**Pattern:**
When the same failure or correction recurs:
1. Ask: can this be a lint rule, a metadata flag, a runtime check, or a script?
2. If yes and the requested scope authorizes that structural change, encode it and delete the repeated instruction.
3. If the change falls outside scope, propose the smallest durable follow-up instead of applying it.
4. If the rule genuinely requires judgment, keep one concise instruction and add an example only when it prevents a likely misread.

**Pick the strongest rung.** When more than one mechanism would work, choose the strongest the situation allows (an unrepresentable state that cannot compile, then a lint or banned API that fails CI, then a canonical helper, then a runtime check), because agents copy whatever the surrounding code already does and a weaker guard becomes the next template.

**Corollary:** Don't paper over symptoms. If the fix is structural, ONLY use the structural fix. The instruction IS the symptom.

**Feedback loop:**
- **Capture every correction.** When the human intervenes or tests fail, decide if it's a one-off or a pattern.
- **Route to the right layer.** One-off -> brain note. Recurring fix -> skill or lint rule. Systemic issue -> principle.
- **Close the loop within scope.** Apply the structural fix when authorized. Otherwise report the follow-up without creating an external ticket or changing unrelated configuration.

**Anti-patterns:**
- Acknowledging without recording ("I'll keep that in mind" does not persist)
- Recording without routing (a brain note about a lint rule that should exist is wasted unless the lint rule gets implemented)
- Fixing without generalizing (fixing one instance while leaving the recurring pattern intact)
