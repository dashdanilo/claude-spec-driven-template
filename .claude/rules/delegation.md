---
paths: "**"
---

# Delegation — who actually writes the code

The main thread **coordinates**; specialists **implement**. This rule loads always, because it is the discipline that decays first.

## The split

| Work | Where | Why |
|---|---|---|
| Exploration — grep, glob, targeted reads, "where does X live?" | inline is fine | cheap, and you want the answer in front of you |
| **Implementation — Edit/Write on source files** | **dispatch to a specialist** | the specialist carries the stack conventions and starts with a clean context |
| Verification — gate, tests, review | dispatch (`tester`, `code-reviewer`, `reviewer`) | an independent context catches what the author's cannot |

## Non-negotiable

- **Never write feature code from the main thread.** If you are about to Edit or Write a source file for the task at hand, dispatch it instead.
- **No specialist for this stack is a gap in the stack plugin, not permission to hand-roll it.** Say so out loud, dispatch to a general-purpose implementer as a stopgap, and flag the missing agent — a general-purpose agent re-discovers the repo on every run and costs multiples of a specialist.
- The main thread owns exactly four things: the plan, the `tasks.md` checkboxes, the gate decision, and the conversation with the human.

## Narrow exceptions

- A one-line fix the gate verifies immediately — cheaper inline than a round-trip.
- The orchestrator's own documents: `tasks.md`, `spec.md`, `plan.md`, `lessons.md`, ADRs.
- The human explicitly asked you to make the edit yourself.

Anything else is a dispatch.

## Why this is a rule and not advice

Doing it yourself always feels faster in the moment, and it never is: the main thread accumulates every file it touches, so by the third task its context is worse than a fresh specialist's — and it is the context the human is sitting in.

Measured on a real project running this template: **71% of `Edit` calls happened in the main thread**, while `Grep`/`Glob` were **100% delegated**. Exploration was being delegated and implementation was not — exactly backwards. The main thread ended up carrying 71% of total token spend, in a system whose own context doc says to keep it lean.

See `.claude/docs/dispatching.md` for *how* to dispatch (parallelism, background, re-review) and `.claude/docs/context-engineering.md` for what to send and take back.
