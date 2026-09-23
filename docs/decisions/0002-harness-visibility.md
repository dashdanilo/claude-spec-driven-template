# 0002 - Harness visibility: a symlink-based harness is invisible to a symlink-blind reader

**Status:** Accepted
**Date:** 2026-09-23
**Decider:** Danilo Rodrigues

## Context

This directory held only [`0001-example.md`](./0001-example.md) until now. The
real decisions about how this harness is distributed and consumed were made
and recorded in the private `njord-app/marketplace` repo instead, because that
is where the multi-repo consequences first showed up:

- **ADR 0001** (marketplace) chose symlinks over copies, a plugin, or a git
  submodule, so a harness change is written once and is live everywhere it is
  linked, with nothing namespaced and nothing excluded.
- **ADR 0003** (marketplace) moved that symlinking to be per-project and
  opt-in, with absolute paths and **nothing committed**: the links live in
  `.git/info/exclude`, never `git ls-files`. This is explicitly what makes it
  safe to link a repo other people share: "a teammate cloning it sees no
  dangling symlink, and CI sees nothing at all."
- **ADR 0004** (marketplace) changed the link granularity from one link per
  whole `skills/`/`agents/` folder to one link per item
  (`.claude/skills/<name> -> <checkout>/baseline/skills/<name>`), so an
  adopting repo's own skills and agents keep working alongside the harness.

That split is wrong for a public template: a reader of this repo cannot see
the reasoning behind its own harness delivery mechanism unless they also have
access to a private org repo. This ADR is the first one written here about the
harness's own visibility, and it treats the three marketplace ADRs above as
the prior record rather than re-litigating them.

The immediate trigger: running [`harness-score`](https://github.com/paladini/harness-score)
(a deterministic, zero-network, zero-LLM CLI that scores a repo's agent
harness 0-108 across six dimensions and maps it to a maturity level L0-L4)
against `njord-back`, `njord-front`, `website`, `sales-funnel`, and this
template itself, on 2026-09-23, produced two distortions:

1. **Skills & Commands scores 0/17 on four of the five repos**, including
   this template's own committed, in-root `.claude/skills -> ../baseline/skills`
   symlink, despite the harness being fully present and working in a live
   Claude Code session in every one of them.
2. **`njord-back` instead scored a misleadingly high L4, 99/108.** A stale
   `.claude/worktrees/<name>/` directory left over from an earlier harness
   run still holds an old, fully vendored (real files, not symlinks) copy of
   48 skills and 20 agents, unrelated to the repo's actual, current, symlinked
   harness state.

### What the mechanism actually is (read from the tool's own source, not guessed)

`harness-score`'s file walker (`packages/cli/src/scan.ts`) does follow
symlinks, but only up to a point, and the point matters:

- A symlinked directory whose realpath resolves **outside the scan root** is
  excluded from the file list, and the code marks the **entire scan**
  `incomplete` (`outside-root-symlink`) rather than silently scoring it as if
  the harness were not there. The tool's own README says an incomplete
  scan's score should not be "publish[ed] ... as authoritative." This is
  exactly ADR 0003/0004's convention: `.claude/skills/<name>` and
  `.claude/agents/<name>.md` are absolute symlinks into a checkout that lives
  elsewhere on disk, deliberately never committed.
- More surprising: an **in-root** symlinked directory does not help either.
  This template's own `.claude/skills -> ../baseline/skills` is git-tracked
  (mode `120000`), relative, and resolves inside the repo. `harness-score`
  still scores it 0/17, because the walker de-duplicates by canonical
  realpath and always keeps the first-encountered **physical** directory over
  any symlink alias to the same target (the code's own comment: "a lexically
  earlier symlink cannot hide the canonical repository path for the same
  target"). `baseline/skills/` gets walked and claimed as the canonical path
  before `.claude/skills` is ever expanded, so every file under it is
  attributed only to `baseline/skills/...`, never to `.claude/skills/...`.
  The individual checks (`SKL-01`..`04`, `AGT-01`..`02`, matched in
  `packages/cli/src/harness/registry.ts` against patterns such as
  `/(^|\/)\.claude\/skills\/[^/]+\/SKILL\.md$/`) require that literal
  `.claude/skills/`, `.cursor/skills/`, or `.agents/skills/` path segment;
  `baseline/skills/` never matches any of them, symlink or not.
- We checked for an escape hatch before concluding there was not one:
  `--help`, the README's "Team customization" section, and the config parser
  (`packages/cli/src/config.ts`). `.harness-score.json` supports `extends`
  (named presets), `rules` (per-check severity `off`/`error`, with three
  credential-leak checks that can never be turned off), and
  `extraRoots`/`scopes` (adds a wholly separate, independently-rooted scan
  that only feeds the `effective` gate, not the default `maturity` gate,
  meant for `~/.claude` user/system scope). None of these remap or alias a
  path for check-matching purposes, and none changes the two behaviors above.
  There is no `--follow-symlinks` flag. This is how the scanner is built, not
  a bug to file or a flag we missed.
- The registry's path patterns are also **unanchored**
  (`(^|\/)\.claude\/skills\/...` matches that segment anywhere in the tree),
  which is the other half of the `njord-back` story: its stale
  `.claude/worktrees/<name>/.claude/skills/...` directory held real files (an
  old full vendor copy, not a symlink), so it counted in full, regardless of
  whether the top-level repo's current harness setup is visible at all.

Net effect: the harness is invisible to `harness-score`, to CI, and to a
fresh clone that has not run `install-harness.sh` locally. Not because of a
bug in the scanner and not because of anything specific to this template, but
because a symlink-delivered harness and a canonical-realpath, in-root-only
file walker are structurally incompatible. `harness-score`'s own score on
this repo therefore understates its harness; it can never overstate it.

## Options considered

1. **Do nothing, ignore the score.**
   - Pros: no work.
   - Cons: a wrong 99/108 on `njord-back` and a wrong 0/17-on-skills
     everywhere else both get treated as fact by anyone who does not know the
     mechanism above, including this template's own new CI job.
2. **Accept and document.** State plainly, here and in a guide, that the
   score is a floor and name both distortions with the concrete evidence
   above, so nobody re-derives it and nobody trusts a 99 or a 0 at face
   value. Point at `install-harness.sh --status`, an existing, already
   uncommitted, always-current command, as how a human actually checks
   what is linked, rather than adding a new artifact.
3. **`install-harness.sh` writes a small, committed marker** (for example
   `.claude/HARNESS.md`) listing the linked skills/agents and the checkout
   path, so a fresh clone, CI, or a human without the harness linked can at
   least see that a harness exists.

### Why option 3 does not pay for itself

Before choosing, we weighed exactly what committing a marker would buy:

- **It does not move the score.** `harness-score`'s skills/agents checks
  require a literal `SKILL.md` (or agent frontmatter file) at a recognized
  path; a prose marker file does not match any `pathRegex`. The dimension
  stays 0/17 regardless. The scanner's design (prefer the canonical
  realpath, exclude out-of-root symlinks) cannot see delegated content by
  construction, and a marker is delegated content read about, not files at,
  the recognized path.
- **It reintroduces the exact cost ADR 0003 spent an ADR removing.** ADR
  0003's decision rests on "nothing is committed ... safe to link a repo
  other people share." A committed marker in an adopting repo would record
  one developer's machine-specific absolute checkout path, differ across
  every teammate who runs the installer from a different location, and turn
  "one command, no diff" into "one command, plus a commit, plus a merge
  conflict the next time a teammate runs it from their own path." ADR 0003's
  own "Negative" section already accepts that a teammate without the harness
  linked "does not have it, and CI never does"; a marker does not change
  that fact, it only makes one developer's local path visible in git history
  for everyone else, which is the specific risk 0003 was written to avoid.
- **The one place a marker could help, this template's own dogfood
  config, already has a committed link** (mode `120000`, relative, in-root),
  making a marker redundant with `git ls-tree` and with `check-index.sh`,
  which already verifies linked names against `baseline/` and would catch
  drift a hand-written marker could silently fall out of sync with.

## Decision

**Option 2: accept and document.**

- This ADR is the durable record of the mechanism, for any reader of this
  public repo.
- [`docs/guides/harness-score.md`](../guides/harness-score.md) is the
  operational guide: how to run the scanner per repo, how to read the six
  dimensions, and the two distortions above with the exact `njord-back`
  example, so nobody trusts a 99 again.
- A `harness-score` CI job is added to this repo's own pipeline, gated at
  `--min-level 2`, the level this repo's own harness actually holds today on
  a clean clone, so the job passes now and fails only on a real regression,
  never on the pre-existing skills/agents undercount.
- We do **not** change `install-harness.sh` or add any new committed
  artifact. The existing, uncommitted `install-harness.sh --status` remains
  the correct way for a human to see what is actually linked in a given
  checkout, and it is always current because it reads the filesystem instead
  of a snapshot that can drift.

## Consequences

### Positive

- No reader of this repo, human or CI, is left to independently rediscover
  why `harness-score` disagrees with reality; the ADR and the guide say it
  plainly, with file:line-level evidence.
- CI now gates on a real, deterministic number for this repo instead of
  either ignoring `harness-score` entirely or silently accepting an
  unexplained low score.
- No new committed artifact, no new drift surface, no risk of reintroducing
  ADR 0003's "nothing is committed" cost into any adopting repo. This
  decision touches nothing about the delivery mechanism itself.
- Public record: the njord repos' own future PRs (not part of this change)
  can point at this ADR instead of re-deriving the same investigation.

### Negative

- The skills/agents undercount is permanent as long as `harness-score`
  canonicalizes by realpath and this harness is delivered by symlink;
  nothing in this repo can fix it locally. Every future reading of the score
  needs the same caveat, forever, until the upstream tool changes or this
  harness stops being symlink-delivered.
- `--min-level 2` only proves this repo has not regressed below what it
  holds today; it does not prove the skills/agents dimension is healthy,
  because the tool cannot see it either way. A real regression in
  `baseline/skills/` (a broken `SKILL.md`, a missing description) would not
  be caught by this gate.
- A future contributor unfamiliar with this ADR could still see "L2, 62/108"
  in CI and assume it means something it does not; the guide mitigates this
  but does not eliminate it.

### Risks accepted

- If `harness-score` ever changes its symlink-canonicalization behavior (see
  "Revisit when"), this repo's documented score would jump, and the ADR's
  explanation would need a superseding note rather than a silent edit.
- The pinned `harness-score` version in CI (see the guide) can go stale;
  bumping it is a deliberate, reviewed step, not automatic, precisely because
  the tool's own semver policy allows the maturity model itself to change in
  a minor version.

## Revisit when

- `harness-score` gains a documented way to alias or remap a path for check
  matching (an `overlay`/`alias` config key, or a `--follow-symlinks` mode
  that keeps every reachable relative path instead of one canonical one).
  At that point option 3 becomes worth re-costing, since the objection above
  is about payoff, not principle.
- The harness delivery mechanism itself changes away from symlinks (tracked
  in the marketplace ADRs' own "Revisit when" sections, for example a `rules`
  field landing in the Claude Code plugin manifest). A copy- or plugin-based
  harness would not have this blind spot and this ADR would need a
  superseding note.
- `njord-back`'s stale worktree (or any repo's) is cleaned up and its score
  drops to reflect reality. Worth a one-line addendum here rather than
  silently letting the next reader assume the 99 was ever real.
