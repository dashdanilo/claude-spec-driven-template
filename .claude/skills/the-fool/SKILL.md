---
name: the-fool
description: Stress-test a plan, spec, decision, or approach before committing to it — devil's advocacy, pre-mortem, red-teaming, assumption-falsification. Use when finalizing a spec.md/plan.md, weighing an ADR or architecture choice, or before a risky/expensive change; or when the user says "poke holes in this", "what could go wrong", "pre-mortem", "challenge this", "red team it". NOT for building the solution.
license: CC-BY-4.0
metadata:
  adapted_from: "the-fool by github.com/Jeffallan (tech-leads-club/agent-skills)"
  portable: true
  version: 1
---

# The Fool — challenge it before you commit

Make a plan/decision **stronger** by attacking it honestly, then synthesizing. Not to build the solution; not to nitpick for its own sake. Portable — works on any decision.

## When to apply

- Before finalizing `specs/<slug>/spec.md` or `plan.md`.
- Weighing an ADR, an architecture choice, or a risky/irreversible change.
- Any decision where being wrong is expensive (auth model, data migration, external integration).

## Method

1. **Steelman first.** Restate the plan/position in its **strongest** form — stronger than it was stated. Confirm you got it right before attacking. Never strawman.
2. **Pick a mode** (or auto-pick from the decision's shape):
   - **Assumptions** — Socratic questions; list the unstated assumptions it rests on.
   - **Counter-argument** — argue the opposite thesis, steel-manned.
   - **Pre-mortem** — "it's 6 months later and this *failed* — why?" Trace the failure chains.
   - **Red team** — an adversary/abuser persona: how would they exploit or break it? (best for auth / tenant-scoping / integration / money paths)
   - **Falsification** — what evidence would prove this wrong? Is that evidence being ignored?
3. **Bias scan.** Name the reasoning distortions in play (sunk cost, confirmation, optimism, anchoring) — implicitly, not as accusations.
4. **Engage.** Present the **3–5 strongest** challenges — concrete and specific, never vague hypotheticals. Ask the user to respond to each **before** you synthesize.
5. **Synthesize.** Fold in the answers: what held up, which objections stick, the unresolved trade-offs, and a **confidence verdict — HIGH / MEDIUM / LOW / PIVOT**. If MEDIUM or LOW, name the **single riskiest assumption** and a **cheap concrete experiment** to test it.

## Rules

- Steelman before challenging; concede points that survive scrutiny.
- Critiques must point toward improvement — not destruction for its own sake.
- Don't override real domain knowledge with generic skepticism.
- Max 3–5 challenges; quality over volume. Apply the frameworks implicitly — don't lecture about them.

## In our flow

Pairs with `spec-reviewer` (which checks a spec is *complete/clear*): the-fool checks whether the plan is *right*. Feed the riskiest-assumption + experiment back into `plan.md`, or record the decision (and why it survived) as an ADR in `docs/decisions/`.
