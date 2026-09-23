# Harness Score: measuring this repo's harness, and its two known blind spots

For anyone who wants to run [`harness-score`](https://github.com/paladini/harness-score)
against this repo (or a project that linked this harness) and make sense of
the number it prints.

## Prerequisites

Node.js on `PATH` (the CLI ships as an npm package; `npx` fetches it, nothing
to install ahead of time). No account, no network access needed at scan time
beyond the initial `npx` fetch, no configuration required to get a first
score.

## What it measures

`harness-score` is a deterministic, zero-LLM, zero-network CLI. It walks a
repository's filesystem, checks for concrete artifacts (a file exists, parses,
matches a pattern), and reports a score out of 108 across six dimensions,
mapped to a maturity level L0 (unharnessed) through L4 (self-correcting):

| Dimension | Points | What it checks for |
|---|---|---|
| Context & Guides | 20 | `AGENTS.md` substance, scoped rules with frontmatter |
| Skills & Commands | 17 | `SKILL.md` files, slash commands, subagent definitions |
| Hooks & Guardrails | 14 | Gate hooks (block risky actions), feedback hooks (lint/format on edit) |
| Sensors & Feedback | 20 | Test runner, linter, type checker, formatter, actual test files |
| CI Feedback | 14 | A pipeline that runs tests/lint/types on every push, pre-commit installed |
| Hygiene & Safety | 23 | `.gitignore`, no leaked secrets, license, lockfile, safe MCP config |

Same repository, same commit: same score, every time. That is what lets it
gate a CI job (see below), and it is also exactly why it cannot see a harness
delivered by symlink: it has no judgment to apply, only a fixed set of path
patterns to match against the files it actually walked.

## Running it

```bash
# human-readable terminal report
npx harness-score

# machine-readable
npx harness-score --json

# markdown report, to a file or stdout
npx harness-score --md report.md
npx harness-score --md -

# CI gate: fail if the score maps below a given level
npx harness-score --min-level 2
```

This repo pins a specific version in CI (`.github/workflows/test.yml`,
`harness-score` job) rather than always fetching latest, and gates at
`--min-level 2`, the level this repo's own harness holds today on a clean
clone. Bump the pin deliberately, after reading the new version's
CHANGELOG, not as a drive-by dependency update: the tool's own semver policy
allows the maturity *model* (what earns points) to change in a minor version,
so an unpinned bump can move this repo's score for reasons that have nothing
to do with anything that changed here.

## Two distortions you will hit on this template's own repos

Full mechanism and the source-level evidence for both:
[`docs/decisions/0002-harness-visibility.md`](../decisions/0002-harness-visibility.md).
The short version, so you do not have to re-derive it:

### 1. Skills & Commands understates every repo that links this harness

This harness is delivered by symlink (see the marketplace repo's ADRs 0001,
0003, 0004, cited in full in ADR 0002 above). `harness-score`'s file walker
de-duplicates by canonical realpath and keeps only the first-encountered
physical directory for a given target, so:

- A repo that links the harness with `install-harness.sh` (absolute,
  per-item symlinks, deliberately uncommitted per ADR 0003) gets an
  `outside-root-symlink` verdict, and the **entire scan** is marked
  incomplete, not just the skills dimension.
- Even this template's own repo, where `.claude/skills -> ../baseline/skills`
  is a committed, relative, in-root symlink, still scores 0/17: the walker
  attributes every file under it to the canonical `baseline/skills/...` path,
  which none of the `SKL-*`/`AGT-*` checks recognize, since they look
  specifically for a `.claude/skills/`, `.cursor/skills/`, or
  `.agents/skills/` path segment.

There is no config flag that fixes this (`.harness-score.json`'s `extends`,
`rules`, and `extraRoots` keys do not remap paths; there is no
`--follow-symlinks` flag). Treat a low or 0 Skills & Commands score on any
repo using this harness as **expected**, not as a sign the harness is
missing. To see what is actually linked in a given checkout, run
`install-harness.sh --status` instead of trusting this dimension.

### 2. A stale nested worktree can inflate the score past what is real

`njord-back` scored a misleading L4, 99/108, on 2026-09-23. The cause: a
leftover `.claude/worktrees/<name>/` directory still held an old, fully
vendored (real files, not symlinks) copy of 48 skills and 20 agents from
before that repo adopted the symlink-based harness. `harness-score`'s path
patterns are unanchored (they match `.claude/skills/<name>/SKILL.md`
*anywhere* in the tree, not just at the repo root), so that stale, unrelated
copy counted in full and pushed the score to L4 while the repo's actual,
current, top-level harness setup was exactly as invisible as every other
repo in this family (distortion #1, above).

Before trusting a high score, check for anything under `.claude/worktrees/`,
`node_modules/`, or any other nested checkout that might hold its own,
possibly stale, copy of harness files. `harness-score` has no way to know
which copy is "the real one."

## Reading a result honestly

Given both distortions run in the same direction (skills/agents undercounted
by symlinks, inflated by stale vendored copies), a score from this family of
repos should always be read as:

- **Context, Hooks, Sensors, CI, Hygiene:** trustworthy as reported, these
  dimensions check for files that are either genuinely committed or genuinely
  absent, and none of them route through the symlink-canonicalization
  behavior above.
- **Skills & Commands:** a floor, not a ceiling, on a repo that links this
  harness. 0/17 does not mean no skills exist; it means `harness-score`
  could not see the ones that do.
- **A surprisingly high score:** worth a manual check for a stale nested copy
  before repeating it anywhere, per the `njord-back` example above.

## Next steps

- [`docs/decisions/0002-harness-visibility.md`](../decisions/0002-harness-visibility.md) - the full decision record, with source-level citations.
- [`ADOPTING.md`](../../ADOPTING.md) - how a project links this harness (the mechanism that causes distortion #1).
- [harness-score's own guide](https://paladini.github.io/harness-score/) - the maturity model and full check catalog, maintained upstream.
