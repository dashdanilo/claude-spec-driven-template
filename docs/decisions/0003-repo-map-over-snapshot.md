# 0003 - Repo map replaces the Repomix snapshot as panoramic context

**Status:** Accepted
**Date:** 2026-09-23
**Decider:** Danilo Rodrigues

## Context

The harness told agents to treat a Repomix snapshot at
`.claude/context/repomix-snapshot.md` as panoramic codebase context:
`analyze-codebase` generated it for any project with 100+ source files,
`codebase-explorer` read it for "what modules exist" / "where does X live"
questions and auto-refreshed it when stale, and a `SessionStart` hook warned
when it aged. The premise was "pack the whole codebase into one file an
agent can read start to end."

Measured against the real repos this harness is used on:

| Repo | Tracked source files | Snapshot size | Approx. tokens |
|---|---:|---:|---:|
| njord-back | 1,106 | 4.5 MB (`files_captured: 877`, undercounted) | ~1,127,000 |
| njord-front | 2,844 | 3.8 MB (`files_captured: 0`, the counter itself was broken) | ~950,000 |
| website | 217 | none generated | n/a |
| sales-funnel | 119 | none generated | n/a |

A 1.1M-token file does not fit any model's context window; reading it whole
was never actually possible, only assumed. In practice it was a grep target
that cost 8+ seconds to regenerate whole (no incremental path), aged
silently between regenerations, and, on njord-front, was already
misreporting its own file count, a sign nobody was checking it. `website`
and `sales-funnel` never crossed the 100-file threshold, so `analyze-codebase`
never generated one for them at all, and `codebase-explorer` had nothing to
fall back to but ad hoc grep/glob, undocumented as the actual behavior.

## Options considered

1. **A small deterministic repo map.** Directory tree with per-directory
   file counts, entry points, test locations, and the commands block from
   `AGENTS.md`. Grows with directory count, not file content.
   - Pros: fits easily regardless of repo size; regenerates in under a
     second; no npx, no network, no Node version dependency; nothing to
     cache or go stale (cheap enough to regenerate on every use).
   - Cons: shallower than reading real file contents. It answers "where
     does X live", not "how does X work".
2. **Keep the snapshot, but only as a grep/read target.** Stop calling it
   "context", add a hard size-budget check, document it as a manual/paste
   tool.
   - Pros: minimal change; some adopters may still want a single-file
     export for a tool with no filesystem access.
   - Cons: as a search mechanism it adds nothing `Grep`/`Glob` do not
     already do directly against live files. No packing step, always
     current, respects `.gitignore` natively. Keeping it as the *default*
     mechanism would mean maintaining a multi-megabyte generated-and-forgotten
     file with no reader and no capability `Grep` lacks.
3. **Drop the snapshot entirely above a threshold.** Let `Grep`/`Glob` plus
   a map do the work, which is what `codebase-explorer` effectively did
   already once a snapshot stopped fitting.
   - Pros: no dead mechanism left running by default.
   - Cons: on its own, loses the "one file to hand to an external tool with
     no filesystem access" use case entirely.

## Decision

We chose **option 1, combined with demoting option 2 to fully manual/opt-in**
(a hybrid of the three, not a pure pick of one):

- **The repo map (`baseline/scripts/repo-map.sh` -> `.claude/context/repo-map.md`)
  becomes the panoramic-context artifact.** `codebase-explorer` runs it fresh
  as its first step for "what exists / where does X live" questions, in
  place of the old snapshot-staleness check. It is cheap enough (see
  Measured below) that there is nothing to cache and nothing to warn about
  going stale. Regenerating it is the freshness strategy.
- **The Repomix snapshot is demoted, not deleted.** `analyze-codebase` no
  longer generates one automatically, `codebase-explorer` no longer reads or
  auto-refreshes one. The `refresh-snapshot` skill still exists, rewritten
  to say plainly what it now is: a manual, opt-in, single-file export for
  handing to some other tool that has no filesystem access, never context a
  Claude Code agent reads itself. `check-snapshot.sh` gained a hard size
  budget (300,000 bytes, ~75k tokens at the repo's own ~4-bytes/token
  estimate) and a `too-large` verdict that fires independent of staleness;
  `check-snapshot-on-session.sh` now warns only on `too-large`, never on
  age, since nothing auto-reads the file anymore and a staleness nag about
  an artifact nobody reads is noise, not signal.
- We did not go with a pure option 3 (delete Repomix outright) because the
  "single file for a tool with no filesystem access" case is real and cheap
  to keep alive once it can no longer masquerade as something the harness
  itself trusts.

### Measured: repo map size on the same repos

Generated with `baseline/scripts/repo-map.sh`, no flags:

| Repo | Tracked files | Repo map size | Approx. tokens | vs. old snapshot |
|---|---:|---:|---:|---:|
| njord-back | 1,106 | 6.1 KB | ~1,500 | ~740x smaller |
| njord-front | 2,844 | 3.8 KB | ~950 | ~1,000x smaller |
| website | 217 | 2.6 KB | ~650 | n/a, no snapshot existed |
| sales-funnel | 119 | 2.1 KB | ~525 | n/a, no snapshot existed |

All four land far under the 75k-token budget the old snapshot never met on
the two repos big enough to have one at all.

## Consequences

### Positive

- `codebase-explorer`'s first step is now something that actually completes
  and actually fits, on every repo measured, not just the ones under 100
  files.
- No caching, no staleness math, no drift for the artifact that matters day
  to day: the repo map is regenerated, not trusted from a prior run.
- The false premise ("this file is context you can read") is gone from
  `codebase-explorer`, `analyze-codebase`, `refresh-snapshot`, and the
  `SessionStart` hook, and none of them silently produce something unusable
  anymore.
- `website` and `sales-funnel`, which never had a snapshot at all under the
  old 100-file threshold, get exactly the same panoramic artifact every
  other repo gets. There is no threshold left to fall below.
- The manual export use case (handing one file to a tool with no filesystem
  access) still works, now honestly labeled and budget-checked instead of
  silently trusted.

### Negative

- The repo map is shallower than a real snapshot read: it cannot answer "how
  does the auth guard actually validate a token", only "where does auth
  code live". `codebase-explorer` still needs `Grep`/`Glob`/`Read` for
  anything past "where".
- The `AGENTS.md` command-block extraction in `repo-map.sh` is a heuristic
  (first fenced block under a heading matching Build/Test/Lint/Command/
  Scripts). A repo whose `AGENTS.md` structures that section differently
  gets a degraded but not broken result ("read AGENTS.md directly").
- An adopter who still wants an always-current Repomix export for an
  external tool now has to run `refresh-snapshot` manually. It is no longer
  produced for them by `analyze-codebase`.

### Risks accepted

- The 300,000-byte / ~75k-token size budget is a judgment call, not derived
  from a model's actual context window. If it turns out too strict or too
  loose in practice, it is a one-line constant to revisit, not a redesign.
- The entry-point and test-location heuristics in `repo-map.sh` were tuned
  against this repo and njord-back/njord-front/website/sales-funnel. A
  repo with an unusual layout (a monorepo with deeply nested packages, say)
  may get a less useful map; it degrades to "grep/glob directly," the same
  fallback that existed before this change.

## Revisit when

- A repo's real `AGENTS.md` structure breaks the command-block heuristic
  often enough that it is worth a second extraction strategy.
- Someone actually needs the manual Repomix export path and finds the
  300,000-byte budget wrong for their case, in either direction.
- The repo map itself needs a second, deeper tier (per-module README
  summaries, say) because "where does X live" stops being enough. At that
  point this ADR should be superseded, not edited.
