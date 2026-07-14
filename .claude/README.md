# `.claude/` — how this is organized

A one-screen map of the layers. Each has a different trigger and job. Put a thing in the layer that matches how it should load.

| Layer | Folder | Loads / fires when | Job |
|---|---|---|---|
| **Agents** | `agents/` | you invoke a subagent (by name or via a driver) | **who** does the work — a role with a persona + instructions, running in its own context |
| **Skills** | `skills/` | the task matches the skill's `description` | **reusable knowledge + workflows** (a `SKILL.md`, optionally with `references/` or `rules/<id>.md`) |
| **Rules** | `rules/` | you edit a file matching the rule's `paths:` glob | **terse, enforceable conventions** — one-liners a reviewer checks |
| **Hooks** | `hooks/` | a tool runs (Bash / Edit / Write / SessionStart / SubagentStop) | **automation & guardrails** (block secrets, protect branches, log agents) |
| **Commands** | `commands/` | you type `/<name>` | **drivers** that orchestrate a multi-step flow in the main thread |
| **Docs / specs** | `docs/`, `specs/` | on demand / per feature | human-facing docs, ADRs, and per-feature `spec.md` / `plan.md` / `tasks.md` |

Also: `scripts/` (shell helpers, e.g. `spec-worktree.sh`, `check-index.sh`), `context/` (generated Repomix snapshot, gitignored), `settings.json` (permissions + hooks).

## Skills: two kinds

- **Workflow skills (portable / stack-agnostic):** the spec-driven flow (`explore`, `write-spec`, `spec-worktree`, `find-existing-first`, `documenting-domains`, `refresh-snapshot`), plus `verify-before-done` (the anti-error gate), `skill-architect`, and `the-fool`. They discover the stack from `AGENTS.md` / tooling, so they fit any repo.
- **Topic skills (stack-assumed):** knowledge tied to a framework. The baseline ships **none** — they arrive from **stack plugins** in the [njord marketplace](https://github.com/njord-app/marketplace) (e.g. `frontend-react`, `backend-nest`), installed per project.

## Agents: two kinds

- **Portable (adapt to any repo):** `reviewer`, `tester`, `code-reviewer`, `codebase-explorer`, `spec-reviewer`, `researcher`, `security-auditor` — they read `AGENTS.md` + `.claude/rules/` and run the repo's own verification.
- **Stack specialists:** none in the baseline — they arrive via stack plugins (e.g. `backend` / `database` / `graphql` for a NestJS/Prisma stack).

## Three principles

1. **One home per topic.** A fact lives in exactly one skill/rule; others cross-link, never copy.
2. **Rule vs skill.** A **rule** states *what* (one line, path-scoped, always in context for that path). A **skill** shows *how + why + example* (loads by task). Project-specific conventions are rules; the richer teaching is skills.
3. **One owner per document.** When `/orchestrate` runs specialists in parallel, each writes only its own outputs — `tasks.md` belongs to the orchestrator (it checks the boxes), `spec.md`/`plan.md` to the author, and a specialist never edits another wave's files. ADRs are append-only (`.claude/rules/adr.md`). This is what keeps parallel agents from clobbering each other.

## Where things point

- Project context & stack → `AGENTS.md` (source of truth), `CLAUDE.md` (Claude-specific extras).
- The index above is kept honest by `.claude/scripts/check-index.sh` (runs on SessionStart; warns when `CLAUDE.md` lists something that no longer exists or misses something on disk).
- Human docs → `docs/` (architecture, conventions, decisions).
