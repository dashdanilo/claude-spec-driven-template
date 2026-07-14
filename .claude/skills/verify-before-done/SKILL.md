---
name: verify-before-done
description: Run the project's own verification (install, codegen, typecheck, build, tests) and confirm it passes before claiming a change is complete, checking a task off, opening a PR, or reporting success. Stack-agnostic — it discovers the commands from the repo, it does not assume a framework. Use after implementing any change and inside automated loops as the gate that must be green before advancing.
metadata:
  portable: true
  applies_to: any repo
  version: 1
---

# Verify before done

Never claim a change is "done", check a task in `tasks.md`, or open a PR without running the project's verification and seeing it pass. This is the gate that keeps automated loops from advancing on broken code. Evidence before assertions.

## When to apply

- After implementing a change or finishing a task
- Before checking a `tasks.md` box, opening a PR, or reporting success
- As the mandatory gate step in a subagent/`/loop` development loop

## Discover the commands (do not assume the stack)

Read, in order, until you know how to build and test THIS repo:

1. `AGENTS.md` / `CLAUDE.md` — a "Build, test, lint" (or similar) section usually lists the exact commands.
2. `package.json` `scripts` (Node), `Makefile`, `pyproject.toml`/`tox.ini` (Python), `Cargo.toml` (Rust), `go.mod` (Go), etc.
3. The `.claude/rules/` for any stack-specific gotchas.

## Use the right runtime

Honor the pinned runtime before running anything: `.nvmrc` / `.tool-versions` / `engines` (Node), the venv/interpreter (Python), the toolchain file (Rust). A wrong runtime version is a common false failure. For nvm repos: `nvm use` (or invoke the pinned version's binary) before install/build.

## Run in this order (skip steps the repo doesn't have)

1. **Install** if the lockfile changed or deps are stale.
2. **Codegen** if the repo generates code (e.g. an ORM client, a GraphQL schema/types). Run it before typecheck so types are current.
3. **Typecheck** (fast signal) — e.g. `tsc --noEmit`.
4. **Build** — the repo's build command.
5. **Tests** for the area you touched (and the broader suite if cheap). Prefer real behavior over mocks.
6. **Lint/format** if the repo gates on it.

## The gate

- Green everywhere → state what you ran and that it passed.
- Anything red → **do not claim done**. Report the failing command and its output, fix, and re-run. In a loop, do not advance to the next task until green.
- Never paraphrase success you did not observe. Paste/summarize the actual result.

## Example (a Node + Prisma + NestJS repo)

Commands come from `AGENTS.md`; here they resolve to:

```bash
nvm use                                   # honor .nvmrc
yarn install                              # if lockfile changed
DATABASE_URL="postgresql://x:x@localhost:5432/x" npx prisma generate  # codegen (offline)
npx tsc --noEmit                          # typecheck
npx nest build                            # build
yarn test:e2e -- <touched-area>           # tests for what changed
```

For a different repo (Vitest, a Python service, etc.) the same six steps map to that repo's commands — discover them, don't hardcode these.
