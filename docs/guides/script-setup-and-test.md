# `script/setup` and `script/test`: Scripts to Rule Them All

For anyone who needs to go from a fresh clone (or a fresh worktree) to a
working, verified environment, without re-deriving the steps from prose.

## Prerequisites

None beyond the repo itself. This guide describes two scripts you write
**once, per project** — the harness does not ship them and does not generate
them. It only calls them when they exist.

## Why

Environment setup written only as prose (`AGENTS.md`, a README section) has
to be rediscovered by every human and every agent that needs it — read, then
translated into commands, every single time. On one project that meant
re-explaining the same ~15 lines of environment (runtime version, which lint
command only checks vs. also rewrites files, which command is the actual
gate) in dozens of subagent briefings, despite all of it already being
written down. The documentation was not the problem; nothing executed it.

The fix, borrowed from GitHub's [Scripts to Rule Them All](https://github.com/github/scripts-to-rule-them-all)
convention, is two executable scripts, committed at the repo root, that
humans, CI, and agents all run the same way:

- **`script/setup`** — takes a clone or worktree from zero to "ready to work
  in". Idempotent: safe to run again on an already-set-up checkout.
- **`script/test`** — the verification this repo considers a gate. The one
  command that must be green before a change counts as done.

The harness's own `spec-worktree` skill runs `script/setup` automatically
after creating a worktree (skip with `--no-setup`), and `verify-before-done`
runs `script/test` instead of rediscovering commands, when either exists. A
project without either script is unaffected — both are no-ops.

## What a good `script/setup` does

- Fixes the runtime version first, before installing anything — `.nvmrc`,
  `.tool-versions`, whatever the repo pins. Installing dependencies under the
  wrong runtime is a common source of failures that look unrelated to the
  actual cause.
- Installs dependencies.
- Creates the local environment file **from a versioned example, only if it
  does not already exist** — never overwrites a file that has real local
  values in it. If the example lists variables the script cannot fill in
  (secrets, per-developer credentials), it lists exactly which ones are
  missing and where to get them; it never invents a value.
- Runs codegen, if the repo has any (ORM client, generated API types).
- Ends by running `script/test` and recording the result (e.g. "42 passing")
  somewhere visible — so the first green run is a known, reproducible
  baseline, not an assumption.

Minimal example (Node project):

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# 1. Runtime version
if [ -f .nvmrc ] && command -v nvm >/dev/null; then
  nvm install >/dev/null
  nvm use
fi

# 2. Dependencies
yarn install

# 3. Local env file — from example, only if missing, never overwritten
if [ -f .env.example ] && [ ! -f .env ]; then
  cp .env.example .env
  echo "Created .env from .env.example — fill in the values it needs."
fi

# 4. Codegen (if applicable)
[ -f prisma/schema.prisma ] && npx prisma generate

# 5. Baseline: run the gate once, know what green looks like
./script/test
```

## What a good `script/test` does

- Runs the same commands a human or CI would run — typecheck, build, the test
  suite, lint. It IS the gate; nothing downstream should need to rediscover
  what "verified" means for this repo.
- Never uses a command that rewrites files as a side effect (e.g. lint with
  `--fix`, a formatter run in write mode). A gate that can silently change
  the code it is checking is not a gate — it is an editor with a confusing
  exit code. Use the check-only variant.
- Runs the suite at least once under a cheap environment variation — a
  different timezone (`TZ=UTC`), a different locale — when the stack supports
  it easily. A suite that only ever runs in the machine's own timezone can be
  green by accident of that machine, and the accident does not travel to CI
  or to a teammate's laptop.

Minimal example:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

npx tsc --noEmit
TZ=UTC yarn test
yarn lint          # check-only; never --fix here
```

## Next steps

- If this repo doesn't have these scripts yet, `analyze-codebase` flags the
  gap in its report when you adopt the harness on an existing project — it
  does not write them for you, since only the team knows what "ready" and
  "verified" mean here.
- See `.claude/scripts/harness/spec-worktree.sh` (via the `spec-worktree`
  skill) for where `script/setup` gets called automatically, and the
  `verify-before-done` skill for where `script/test` becomes the gate.
