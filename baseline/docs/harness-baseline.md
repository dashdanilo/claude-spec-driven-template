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

<!-- instrument-epoch: 2026-09-09 -->
<!-- harness-report.sh reads this marker to know where "current" data starts;
     agent-log.txt lines timestamped before it are excluded from headline
     stats and reported separately, with the reason. If a future fix
     invalidates everything before it the same way, add another
     `instrument-epoch:` marker in that section — the script takes the
     latest one it finds, so this file is the only place that needs editing. -->


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

## 2026-09-10 — A/B: the current driver against the one it replaced

The first run instrumented correctly, and the first real comparison. Same spec
(16 unit-test tasks for pure helpers in njord-back), same 16 targets, same
baseline (14 suites / 190 tests), same fixed instrument. One variable changed:
the driver. Run 1 used the current `orchestrate` skill (132 lines). Run 2 used
the 53-line `commands/orchestrate.md` that njord-back's `develop` still ships.

| | run 1 (current) | run 2 (old) | |
|---|---:|---:|---|
| tasks delivered | 16 | 16 | |
| dispatches | 8 | 53 | 6.6x |
| new tokens | 1,776,741 | 7,708,367 | **4.34x** |
| cache reads | 26.3M | 68.4M | 2.6x |
| implementation tokens per task | ~52k | ~164k | 3.2x |
| tests produced | 220 | 548 | 2.5x |
| production findings | 2 | 17 | |

**Where the old driver's money went:** `code-reviewer` 40.8%, implementation
34.0%, `tester` 23.9%. The `tester` wrote **nothing in 16 of 16 dispatches** —
each time it audited the coverage, found no gap, and returned. With no
class-to-gates matrix the old driver dispatches it even on tasks whose
deliverable is a test file. That waste alone cost more than the whole of run 1.

**Against the claims table above.** Dispatches per message: run 1 sent its wave
three-in-one, the first fan-out on record — confirmed. Unattributed dispatches:
0% in both runs — confirmed. Edit delegated: run 1 measured 92% (37 of 40),
confirmed in direction but weakly, because every task created a new file, the
easiest possible class to delegate. Run 2's 100% is an artifact (see below).

**Against the imported TLC hypothesis.** Implementation alone cost 3.2x per task
under one-dispatch-per-task, against TLC's ~2.4x between the same two shapes.
Different codebase, different work, different tool — the ratio reproduced. The
shape stays established; the number is now ours, not borrowed.

**A second effect nobody had measured: coherence.** Run 2's 16 files came from
16 independent contexts, and the branch review listed five different known-bug
markers, two languages in test titles and three fixture-naming styles. Run 1
produced the same 16 files from three clusters with one convention. Cohesion
buys consistency, not only budget.

**What the A/B does not prove.**
- Run 2 produced more tests and more findings, and the main cause was the
  orchestrator: from its fifth task on, the implementation briefing required
  proving that central assertions kill a mutation — an instruction run 1 never
  had. The bias runs in favour of the old driver, and it still cost 4.34x.
- Run 2's delegation reads 100% because the orchestrator edited its own
  documents through `Bash`, which `log-edit.sh` does not see. The two
  percentages are not comparable. Instrumentation hole, **closed 2026-09-12**
  — see that dated section below for what changed and why every number in
  this file predates a wider definition of "edit" than any report produced
  after that date.
- Two run-2 dispatches were killed by a rate limit and never fired
  `SubagentStop`; the log understates run 2 by at least 97,478 tokens.
- n=1 per driver.

**Decision recorded.** The current driver is the one to adopt. What run 2 did
better — per-task review found real assertion gaps in three of its first four
tasks, and the mutation requirement stopped them — is ported into it rather
than kept by keeping the old driver: review per cluster, falsifiability in the
implementation handoff, an environment-variation checklist for the branch
review, and no verification agent writing to a tracked file. Projection, not
measurement: ~2.3M for the same spec, still ~3.3x under the old driver.

## 2026-09-12 — the Bash write blind spot is closed; the delegation series has a new denominator

`log-edit.sh` was only ever registered on `PreToolUse` for
`Edit|Write|MultiEdit|NotebookEdit`. A write done through `Bash` — a redirect,
`sed -i`, `tee`, `cp`, `mv` — was invisible to it. The 2026-09-10 A/B above
caught this in the act: run 2's orchestrator edited its own tracked documents
through `Bash` and reported **100% delegated**, which was never a real number,
only a blind spot reading as perfection. The error runs optimistic — the worst
direction for a report whose whole job is "is this being used as designed."

`log-edit.sh` now also runs on `PreToolUse`/`Bash`. It recovers a write from
the command with a small character-level lexer (not a full shell parser —
tracks quote state, recognizes `>`/`>>`, `sed -i`, `tee`, `cp`, `mv`, and
explicitly skips `2>`/`&>`/`>&` and `[[ ]]`/`(( ))`), and logs the target only
when it resolves **inside the repo** — `/dev/null`, `/tmp`, the session
scratchpad and anything else outside the project are silently dropped, by one
rule instead of a growing exclude list. A target it cannot resolve to a
literal path (a shell variable, a command substitution) is not dropped either:
it is logged with `path` equal to `?`, because the thread is still known and
the delegation count still needs it — only the by-extension breakdown loses
that row, and `harness-report.sh` says how many it dropped rather than doing
it quietly.

**This changes the denominator, not just the detector.** Every delegation
percentage in this file — the 29% baseline, the 92%/100% A/B pair above — was
computed over Edit/Write/MultiEdit/NotebookEdit only. A percentage measured
after 2026-09-12 also counts Bash-recovered writes, so it can move for a
reason that has nothing to do with how much work is actually delegated: the
set of things being counted got bigger. **Do not compare a pre-2026-09-12
delegation number against a post-2026-09-12 one as if they were the same
series.** Read each on its own side of that date; a rise or fall across it is
not yet evidence of anything.

**What is still not measured.** How much of real delegation was previously
uncounted because it happened through Bash — that requires a report from a
real implementation session run after this fix, compared against one run
before it on the same kind of work. No such pair exists yet.

## 2026-09-12 — subagent token totals were double-counted; the headline now only counts reliable metric

`log-agent.sh`'s degree-3 fallback (no `agent_transcript_path`, no `agent_id`
in the payload — older clients only) picks the newest-by-mtime transcript in
the session's `subagents/` directory and was always marked `approx=1` for
that reason. What the comment did not account for: in a parallel wave, every
`SubagentStop` in that wave resolves to the **same** newest file, and degree
3 copied that file's metrics into every line, not just the first. The lines
did not merely guess wrong — they summed the same transcript's tokens once
per subagent in the wave.

Measured on this machine's own `.claude/agent-log.txt` (135 lines) before the
fix: 22 lines carried `approx=1`, all with the correct `agent=` (that part
comes straight from the payload, not the guessed file, so attribution was
never the problem — the metrics were). Three of those lines shared
`tokens=486296`, two shared `tokens=293605`, two shared `tokens=115571` — six
lines, three transcripts, charged as six. Total subagent tokens reported:
11,718,022. Of that, 4,830,845 (41%) sat in `approx=1` lines — a number with
the same weight in the total as every measured one, presented with no visual
difference from it.

**The fix.** `log-agent.sh` now keeps an "already charged" registry
(`.claude/.agent-log-consumed`, gitignored, keyed by session) and checks it
before degree 3 reports a transcript's metrics. The first `SubagentStop` to
land on a given file in a session gets its real tokens/cached/dur/tools; every
later one that resolves to the *same* file gets `agent=` (still reliable) and
`dup=1`, with no metric fields at all — a missing number, not someone else's
number. `harness-report.sh` now excludes every `approx=1` line's tokens from
the headline "subagent tokens" total (a `dup=1` line, having no `tokens=`
field, already contributes 0) and reports the approximate share on its own
line instead — see the report's own output for the shape.

**This changes comparability again, the same way the 2026-09-12 delegation
entry above does for edits.** Every "subagent tokens" figure in this file —
11.5M in the original baseline, 1,776,741 / 7,708,367 in the A/B — was read
off a total that mixed reliable and (sometimes doubled) approximate metric
with no way to tell them apart after the fact. A token total measured after
this fix only counts lines with real, uniquely-attributed metric; a total
measured before it does not, and the two are not the same series. Read each
on its own side of this date.

**What is still not measured.** Whether degree 3 still fires at all against
a current Claude Code client — the fallback exists for older clients that
omit `agent_transcript_path`/`agent_id`, and if the current client always
sends one of those, this whole path (and the bug in it) may already be
dormant in practice. That requires checking a live payload from a current
session, not a hook-log after the fact.

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
