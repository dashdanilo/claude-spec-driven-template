---
name: diagnosing-bugs
description: Disciplined diagnosis loop for hard bugs and performance regressions. Use when the user says "debug this" / "diagnose", or reports something broken, throwing, failing, flaky, or slow. Stack-agnostic. NOT for trivial one-line fixes.
license: MIT
metadata:
  adapted_from: "diagnosing-bugs by Matt Pocock (github.com/mattpocock/skills, MIT)"
  portable: true
  version: 1
---

# Diagnosing bugs

A discipline for hard bugs. Skip a phase only when you can justify it out loud.

Before exploring: read `AGENTS.md` / `CLAUDE.md` (and any nested `src/<folder>/CLAUDE.md`) for the mental model of the modules involved, and check the ADRs in `docs/decisions/` for the area you're touching.

## Phase 1 — Build a feedback loop

**This is the skill.** Everything else is mechanical. If you have a **tight** pass/fail signal that goes red on *this* bug, you will find the cause — bisection, hypothesis-testing, and instrumentation all just consume it. Without one, no amount of staring at code will save you.

Spend disproportionate effort here. Be aggressive, be creative, refuse to give up.

### Ways to build one, roughly in this order

1. **Failing test** at whatever seam reaches the bug (unit / integration / e2e).
2. **HTTP script** (curl) against a running dev server.
3. **CLI invocation** with a fixture input, diffed against a known-good snapshot.
4. **Headless browser script** driving the UI, asserting on DOM / console / network.
5. **Replay a captured trace** — save a real request/payload/event log and replay it through the code path in isolation.
6. **Throwaway harness** — a minimal subset of the system (one service, mocked deps) that hits the bug in a single call.
7. **Property / fuzz loop** — for "sometimes wrong output", run many random inputs and look for the failure mode.
8. **Bisection harness** — if it appeared between two known states (commit, dataset, version), automate "boot at state X, check, repeat" so `git bisect run` can drive it.
9. **Differential loop** — same input through old vs new (or two configs), diff the outputs.
10. **Human-in-the-loop script** — last resort. If a human must click, drive them with a structured script so the loop stays repeatable and its output feeds back to you.

### Tighten it

Treat the loop as a product. Once you have *a* loop, make it **faster** (cache setup, skip unrelated init, narrow scope), **sharper** (assert the specific symptom, not "didn't crash"), and **more deterministic** (pin time, seed RNG, isolate the filesystem, freeze the network). A 30-second flaky loop is barely better than none; a 2-second deterministic one is a superpower.

### Non-deterministic bugs

The goal is not a clean repro but a **higher reproduction rate**. Loop the trigger 100×, parallelise, add stress, narrow timing windows. A 50%-flake bug is debuggable; a 1% one is not — keep raising the rate until it is.

### When you genuinely cannot build a loop

Stop and say so. List what you tried, and ask for: access to an environment that reproduces it, a captured artifact (HAR, log dump, recording with timestamps), or permission to add temporary instrumentation. **Do not proceed to hypothesise without a loop.**

### Gate — a tight loop that goes red

Phase 1 is done when you can name **one command** you have **already run at least once** (paste the invocation and its output), and it is:

- [ ] **Red-capable** — drives the actual bug path and asserts the **user's exact symptom**, so it goes red now and green once fixed. Not "runs without erroring".
- [ ] **Deterministic** — same verdict every run (flaky bugs: a pinned, high reproduction rate).
- [ ] **Fast** — seconds, not minutes.
- [ ] **Agent-runnable** — you can run it unattended.

> If you catch yourself reading code to build a theory before this command exists, **stop**. Jumping straight to a hypothesis is the exact failure this skill prevents. No red-capable command, no Phase 2.

## Phase 2 — Reproduce, then minimise

Run the loop. Watch it go red.

- [ ] It produces the failure the **user** described — not a different one that happens to be nearby. Wrong bug = wrong fix.
- [ ] It reproduces across runs (or at a high enough rate to debug against).
- [ ] You captured the exact symptom (error, wrong output, timing) so later phases can verify the fix addresses it.

Then **minimise**: shrink to the smallest scenario that still goes red. Cut inputs, callers, config, data, and steps **one at a time**, re-running after each cut. Done when **every remaining element is load-bearing** — removing any one turns it green.

A minimal repro shrinks the hypothesis space in Phase 3 and becomes the regression test in Phase 5. Do not proceed until you have reproduced **and** minimised.

## Phase 3 — Hypothesise

Generate **3-5 ranked hypotheses before testing any of them**. Generating one at a time anchors you on the first plausible idea.

Each must be **falsifiable** — state the prediction:

> "If X is the cause, then changing Y makes the bug disappear / changing Z makes it worse."

If you cannot state the prediction, it is a vibe. Discard or sharpen it.

**Show the ranked list to the user before testing.** They often re-rank it instantly ("we just deployed a change to #3") or have already ruled some out. Cheap checkpoint, big saving. Don't block on it — proceed with your ranking if they're away.

## Phase 4 — Instrument

Each probe maps to a specific prediction from Phase 3. **Change one variable at a time.**

1. **Debugger / REPL** if the environment supports it. One breakpoint beats ten logs.
2. **Targeted logs** at the boundaries that distinguish the hypotheses.
3. Never "log everything and grep".

**Tag every debug log** with a unique prefix, e.g. `[DEBUG-a4f2]` — cleanup later is a single grep. Untagged logs survive; tagged logs die.

**Performance regressions:** logs are usually the wrong tool. Establish a baseline measurement (timing harness, profiler, query plan), then bisect. Measure first, fix second.

## Phase 5 — Fix + regression test

Write the regression test **before the fix** — but only if a **correct seam** exists: one where the test exercises the real bug pattern as it occurs at the call site. A seam that is too shallow (a unit test that can't replicate the chain that triggered it) gives false confidence.

**If no correct seam exists, that is itself the finding.** Say so — the architecture is preventing the bug from being locked down.

With a correct seam:

1. Turn the minimised repro into a failing test (the `tester` agent can write it in the repo's own framework).
2. Watch it fail.
3. Apply the fix.
4. Watch it pass.
5. Re-run the Phase 1 loop against the original, un-minimised scenario.

## Phase 6 — Cleanup + post-mortem

Before declaring done:

- [ ] The original repro no longer reproduces (re-run the Phase 1 loop)
- [ ] The regression test passes — or the absence of a seam is documented
- [ ] All `[DEBUG-...]` instrumentation removed (grep the prefix)
- [ ] Throwaway harnesses deleted
- [ ] `verify-before-done` is green
- [ ] The hypothesis that turned out **correct** is stated in the commit / PR body — so the next debugger learns

**Then ask: what would have prevented this bug?** If the answer is architectural (no good test seam, tangled callers, hidden coupling), record it as an ADR in `docs/decisions/` or a pattern in `docs/patterns/`. Make that recommendation **after** the fix lands — you know more now than when you started.
