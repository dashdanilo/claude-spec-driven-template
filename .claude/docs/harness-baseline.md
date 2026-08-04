# Harness baseline — the numbers to beat

Reference measurements for `/harness-report`. Without a baseline a report is a
number with no opinion; this file is what makes it a verdict.

## Where these came from

Measured on 2026-08-03 from the transcripts of a real project running this
template: **22 sessions, 54 subagent dispatches, ~11.5M tokens**. Not a
simulation and not a target pulled from intuition — this is what the harness
actually did before the corrections listed below.

## The baseline

| metric | measured | what it means | good direction |
|---|---:|---|:---:|
| **Edit delegated** | **29%** | 777 `Edit` calls in the main thread against 316 in specialists, while `Grep`/`Glob` were 100% delegated — exploration was delegated and implementation was not, exactly backwards | ↑ |
| **Main-thread token share** | **71%** | 8.19M of 11.5M, in a system whose own `context-engineering.md` says to keep the main thread lean | ↓ |
| **Dispatches per message** | **1.0** | 54 of 54 went out one per message, so no wave plan ever fanned out | ↑ |
| `/orchestrate` runs | **2** | against 729 free human prompts — the pipeline was executed by hand | ↑ |
| Unattributed dispatches | **77%** | `log-agent.sh` recorded `agent=?` in 183 of 238 events | ↓ |
| Uncollected background agents | **2** | left open for 16 days across a suspended session | 0 |

## What changed after it, and what that means for reading a new report

Between the baseline and now, four corrections landed. **None of them has been
re-measured** — they are hypotheses with reasoning behind them, not verified
outcomes. Reading a fresh report is how they get judged:

| change | the claim it makes | the number that would confirm it |
|---|---|---|
| `rules/delegation.md` (always loaded) | stating the rule raises delegation | Edit delegated well above 29% |
| `/orchestrate` Step 3 rewritten per-wave | waves actually fan out | dispatches per message above 1.0 |
| `/orchestrate` Step 0 + class-to-gates matrix | less ceremony means the command gets used | `/orchestrate` runs above 2 |
| `log-agent.sh` reading the subagent transcript | dispatches become attributable | unattributed near 0 |

The honest possibility is that the delegation number **does not move**. The rule
already existed inside `/orchestrate` before it was promoted to an always-loaded
rule, and the 29% was measured with it in place. If a fresh report still shows
roughly 29%, the conclusion is that prose does not fix this and the next step is
a different mechanism, not a better sentence.

## Reading a report honestly

- **A small sample is not a trend.** A handful of edits in one session says
  nothing. Compare across sessions, and prefer the direction over the value.
- **`thread unknown` is not zero-cost.** Thread detection is a heuristic on the
  hook payload. If unknowns dominate, the report is describing the detector, not
  the behaviour.
- **A good number in a session that did no implementation is meaningless.** A
  session that only read files delegates nothing because there was nothing to
  delegate.
- The logs are gitignored and per-checkout. They measure *this* working copy,
  not the team.

## Updating this file

When a measurement is taken that is broad enough to replace the baseline, add a
new dated section rather than editing the table above. The trail of what the
harness used to do is the point — the same reason `.claude/rules/adr.md` makes
decisions append-only.
