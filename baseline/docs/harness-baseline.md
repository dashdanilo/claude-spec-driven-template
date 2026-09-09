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

## Imported hypotheses — not ours, not measured here

Numbers this harness now acts on that came from **someone else's benchmark**. They are flagged so a future reader knows which figures are earned and which are borrowed.

**~3 cohesive clusters, 5-7 tasks each** — the grouping rule in `/orchestrate` Step 1 and `/wave`.

| source | [Tech Leads Club](https://agent-skills.techleads.club/tlc-spec-driven/), an 18-task Stripe epic |
|---|---|
| method | one codebase, one run per architecture, four architectures |
| what it showed | one-agent-per-task is worst on every axis (25M tokens, 43m, 0.81); ~3 clusters best (10.5M, 18m, 0.95) and finishes at 26% of the window instead of 74% |
| what is solid | the **shape** — granularity destroys quality, and more workers can leave the main thread fatter because every summary returns to it |
| what is not | the **number**. n=1 per cell, and its own authors call the 0.93 vs 0.95 quality gap statistically indistinguishable |

**What would confirm or refute it here:** run `/orchestrate` on a real spec of roughly this size and compare a `/harness-report` against the rows above. The figures that matter are tokens, wall time, and how much of the window is left at the end — that last one is the actual claim, since the token cost at 18 tasks is a wash.

**Why adopt before measuring.** Our own baseline says the opposite failure: 1.0 dispatches per message and 29% of `Edit` delegated, meaning we sit near the *inline* row while `/orchestrate` as written would have produced the *per-task* row. Both directions are wrong and the correction points the same way, so the shape is worth adopting now. If our own numbers land elsewhere, the number changes and the shape stays.

## 2026-09-09 — the instrument was broken; no report before this date is usable

The first attempt to re-measure the four claims above found that the two hooks
producing the data were wrong in three ways. All three were caught by capturing
real hook payloads and comparing them against what the hooks logged, in one
session on this repository.

| bug | effect on the numbers | direction |
|---|---|:---:|
| `log-edit.sh` inferred the thread from `transcript_path`, which points at the **main** session even inside a subagent | every specialist edit counted as a main-thread edit; a session with two active `implementer` dispatches reported **`DELEGATED 0%`** | understates delegation |
| `log-agent.sh` summed only `input_tokens + output_tokens` | a dispatch that created 20,347 cache tokens and read 18,592 more logged **`tokens=169`**, ~120x low | understates subagent cost |
| `log-agent.sh` picked the subagent transcript by newest **mtime** | in a parallel wave every `SubagentStop` resolved to the same file, so N agents produced N lines carrying the last one's identity and cost | destroys attribution exactly in the wave case |

All three are fixed. Verified live: two subagents dispatched in the same
message, one second apart, were attributed to their own types with their own
costs and zero `approx=1`; and `.claude/tool-log.txt` recorded the same
`implementer` as `main` at 03:13:34 and as `sub` at 03:13:45, across the edit
that landed the fix.

**What this means for the four claims in the table above.** None of them has
been judged yet. The delegation row in particular cannot be read from any
report produced before today: the detector answered `main` regardless of the
truth, so a low percentage measured with it is evidence about the detector and
nothing else. The 29% baseline itself survives — it was computed from
transcripts in 2026-08-03, not from these hooks — but every comparison against
it since the hooks landed was invalid.

**What is still not measured.** The delegation ratio in a real implementation
session. `.claude/tool-log.txt` is empty in every njord checkout, because the
hooks were never registered there — the harness has never been adopted in a
repository while real feature work ran through it. That run is still the open
item, and it is now the *first* one that can produce a number worth reading.

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
