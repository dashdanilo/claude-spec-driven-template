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

If the change touched a screen, also run `verify-ui` and fold its driven-flow claim into the same `.claude/verification/` report before calling this gate green - install/typecheck/build/tests never prove a screen rendered correctly.

## Discover the commands (do not assume the stack)

Check first, before anything else: does the repo have an executable `script/test` at its root (the Scripts to Rule Them All convention — `docs/guides/script-setup-and-test.md`)? If so, **that is the gate** — run it instead of rediscovering commands from `AGENTS.md`/`package.json`/etc. It already encodes the repo's own order (install, codegen, typecheck, build, tests) and its own exceptions (e.g. a lint step that only checks, never `--fix`s). Do not second-guess it by also running the steps it already runs.

Without `script/test`, read, in order, until you know how to build and test THIS repo:

1. `AGENTS.md` / `CLAUDE.md` — a "Build, test, lint" (or similar) section usually lists the exact commands.
2. `package.json` `scripts` (Node), `Makefile`, `pyproject.toml`/`tox.ini` (Python), `Cargo.toml` (Rust), `go.mod` (Go), etc.
3. The `.claude/rules/` for any stack-specific gotchas.

Same split for getting the environment ready in the first place: if the repo has an executable `script/setup`, run it to install/codegen instead of assembling those steps by hand. Without one, do them individually as below.

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

## Evidence or zero

A green gate above is necessary, not sufficient: "I ran the tests" is still just your word for it. Prove it instead.

1. Write a short report to `.claude/verification/<YYYY-MM-DD>-<slug>.md` (today's date, a short kebab-case name for the task) and refresh `.claude/verification/latest.md` to the same content. Both are gitignored, a per-clone artifact of this one run, not something a teammate reviews.
2. Two required sections. `## Commands`: one bullet per command you actually ran, with its exit code, e.g. `` - `yarn test` -> exit 0 ``. `## Claims`: one bullet per thing you are claiming true about the change, each carrying evidence: a `file:line` citation, or a backtick-quoted reference to a command already listed above. A claim with nothing behind it counts as zero, not as done.
3. **If a spec or plan with acceptance criteria is active for this work**, every criterion becomes exactly one line in `## Claims`, in one of two forms, never left out entirely:
   - Met: `- acceptance criterion <N> is covered (evidence: <file:line or `command`>)`, evidence pointing at the test or behavior that satisfies it.
   - Not covered: `- acceptance criterion <N> is not covered: <reason>` still needs evidence per `verify-gate.py`'s contract (it accepts any `file:line` or command reference, not just a passing one), so cite the criterion's own line in `spec.md`/`plan.md`, e.g. `(evidence: specs/2026-06-21-dark-mode/spec.md:34)`, and say in the claim text why (out of scope, deferred, blocked). A criterion silently missing from `## Claims` is what this step exists to prevent, not a smaller violation than a wrong claim.
4. Run `baseline/scripts/verify-gate.py .claude/verification/latest.md` (`.claude/scripts/harness/verify-gate.py` in a project that linked the harness). Only claim done once it exits 0; `--json` for a machine-readable result. The script's own header documents the exact format it checks: it verifies every claim carries evidence, it does not know what an "acceptance criterion" is, so the wording above has to satisfy the same `- <claim> (evidence: <file:line or `command`>)` shape it already parses. No change to the script itself should be needed; if one ever does look necessary, describe the gap in your report rather than editing `verify-gate.py` from this skill.

If the repo has `script/test`, it is still the gate, unchanged from above. The report records what you claim from its output; it is not a second gate running the same commands twice.

## Prove the test discriminates

Before a passing test counts as evidence for a behavior claim, break that behavior once and watch the test go red. Do it on a COPY in the scratchpad with the import redirected at the copy, never on the file under review: edit the copy, run the test against it, confirm it fails, then confirm `git status` on the real tree is still clean.

This is the floor: apply it by hand to the one or two load-bearing assertions for the claim, not to every test in the suite, since the cost adds up fast. If the repo has a mutation-testing runner, use it instead where it is cheap enough on the touched area; it is the stronger version of the same check.

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
