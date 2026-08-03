---
name: grilling
description: Relentless one-question-at-a-time interview that walks a decision tree to lock open decisions, resolving dependencies in order and recommending an answer for each. Use to turn an ambiguous decision into a shared, committed understanding; when the user says "grill me", "interrogate this", "walk me through the decisions"; or when another skill needs a rigorous decision-locking pass. NOT for generating options (see `explore`) or attacking a finished plan (see `devils-advocate`).
license: MIT
metadata:
  adapted_from: "grilling by Matt Pocock (github.com/mattpocock/skills, MIT)"
  portable: true
  version: 1
---

# Grilling — lock the decision, one question at a time

Interview the user relentlessly until you reach a shared, committed understanding of the decision at hand. The output is not code — it is alignment.

## Method

1. **Walk the decision tree in dependency order.** Resolve one decision before the one that depends on it. Do not jump to the solution.
2. **One question at a time.** Ask, then wait for the answer before the next. Multiple questions at once are bewildering — never batch them.
3. **Separate fact from decision.** If something is a *fact* discoverable in the environment (filesystem, tools, docs, code), look it up yourself — do not ask. Only *decisions* go to the user.
4. **Recommend in every question.** Never ask open-ended. Propose the answer you think is right and let the user confirm or veto it.
5. **Gate on shared understanding.** Do not act until the user confirms the picture is settled.

## In our flow

- `explore` calls grilling when its "Discuss" step needs decision-by-decision rigor instead of loose back-and-forth.
- Portable and spec-agnostic: use it to lock any decision — an architecture choice, a trade-off — even one that will never become a spec.
- Pairs opposite `devils-advocate`: grilling *builds* the decision; `devils-advocate` *attacks* the decision once built.
