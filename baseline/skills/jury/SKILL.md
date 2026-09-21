---
name: jury
description: Decide between competing options with a panel of subagents that argue independently, then commit to a verdict. Use for a contested call where one perspective is not enough — architecture, vendor, migration path, build-vs-buy — and where being wrong is expensive. NOT for shaping an idea (`explore`), locking decisions with a human (`grilling`), or attacking a plan you already chose (`devils-advocate`).
---

# Jury — decide, do not deliberate forever

`grilling` **builds** a decision with the human. `devils-advocate` **attacks** one
already made. Neither **chooses between options**. That is this.

Expensive on purpose: three to five subagents, two rounds. Use it where being
wrong costs more than the panel does — and nowhere else.

Adapted from `the-jury` by [Tech Leads Club](https://agent-skills.techleads.club/skills/the-jury/) (CC-BY-4.0).

## 1 — Frame

You are the **foreman**. Before assembling anyone:

- State the decision as a question with **concrete, named options**. "Which
  database" is not a decision; "Postgres or DynamoDB for the event log" is.
- Define **2-4 scoring criteria** — the rubric. Write them down before you hear
  any argument, or the rubric will be shaped by the arguments.
- Gather the evidence every juror gets: the same files, numbers and constraints.

If the options are not yet clear, stop — you need `explore`, not a jury.

## 2 — Assemble

Three to five jurors, **odd**, with three mandatory roles:

| role | job |
|---|---|
| **Proponent** | the strongest possible case for one option |
| **Skeptic** | the strongest possible case against it |
| **Integrator** | weighs both and resists the emerging consensus |

Give each juror **one analytical lens** — pre-mortem, red-team,
assumption-surfacing, cost-over-time, operability — so they fail differently.

**Cap at five.** Past that a panel adds correlated noise, not signal: jurors on
the same evidence converge, and you pay for agreement you already had. This is
the same effect measured on dispatch granularity in `harness-baseline.md`, from a
different direction.

## 3 — Round one, blind

Dispatch every juror **in one message**, so they run concurrently and none can
see another's position. Anchoring is the failure this guards against, and it is
the single most important gate in the whole method.

Our subagents are context-isolated, so blindness is structural rather than a rule
you have to trust — but only if you dispatch them **together**. Dispatch them one
at a time and you have to feed each one the conversation, which destroys it.

Each juror returns:

- **Position** — which option, in one line
- **Top arguments** — at most three, against the rubric
- **Evidence grade** — **A** direct proof · **B** strong indirect · **C** informed
  reasoning · **D** anecdote
- **Assumptions** it is resting on
- **Confidence** 0-100

## 4 — Round two, anonymised

Strip identity: relabel positions neutrally before showing them back. A juror
should argue against a *position*, not against a *colleague*.

Two rules:

- **Steelman before rebutting.** Restate the opposing position in its strongest
  form first, and get it right.
- **A change of mind must cite the specific new argument that caused it.** A flip
  with no citation is a bandwagon flip: flag it.

Stop after round two, or earlier once positions stop moving. There is no round
three — panels that keep talking converge on the loudest juror.

## 5 — Verdict

Tally **confidence-weighted**, not by headcount. Ties break on argument quality
against the rubric, never on votes.

If round two showed bandwagon flips, **discard it** and fall back to the blind
round-one aggregate, at LOW confidence. A panel that agreed by contagion has told
you nothing.

Cap confidence when the evidence is thin: no verdict is HIGH on a panel whose
best grade is C.

**There is always a verdict.** "The panel could not decide" is not an allowed
outcome — that is the foreman refusing to do the one job the panel was convened
for.

```
Verdict     <one actionable line>
Confidence  HIGH | MEDIUM | LOW | PIVOT
Why         <up to 5 ranked reasons, tied to the rubric and the evidence>
Dissent     <the strongest minority view, in one line, preserved not erased>
Riskiest    <the single claim that, if false, breaks this>
Test        <one concrete experiment that would check it>
Next        <one action that can start in minutes>
```

## In our flow

- A verdict that changes how the system is built is an **ADR** in
  `docs/decisions/` — `.claude/rules/harness/adr.md` applies, so it is append-only and a
  later reversal supersedes rather than rewrites. Carry **Dissent** and
  **Riskiest** into it: an ADR that records only the winning argument is the one
  nobody can re-evaluate later.
- **PIVOT** means the options were wrong, not that one of them lost. Go back to
  `explore`.
- Do not run a jury on a decision you have already made. That is
  `devils-advocate`, and pretending otherwise wastes five agents on theatre.
