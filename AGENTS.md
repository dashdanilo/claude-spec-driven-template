# claude-spec-driven-template

> Cross-tool source of truth. Read by any AI coding agent: Codex, Cursor, Gemini CLI, GitHub Copilot, Windsurf, Aider, Claude Code, and others that support the AGENTS.md convention.
>
> Tool-specific additions live in their own files:
> - Claude Code: [`CLAUDE.md`](./CLAUDE.md) (stub pointing here + Claude-specific extras)
> - GitHub Copilot: [`.github/copilot-instructions.md`](./.github/copilot-instructions.md) (stub pointing here + Copilot-specific extras)
> - Gemini CLI: `GEMINI.md` (when present)
> - Cursor: `.cursor/rules/` (when present)

A stack-agnostic template repository for structuring AI-enabled projects around spec-driven development. Provides folder layout, agent configuration, skills, subagents, hooks, and workflow patterns that work across Claude Code, GitHub Copilot, and other AGENTS.md-compatible tools.

The repo you are working in **is the template itself**, not an application built from it. There is no runtime code to execute, no server to run, no build to compile. Contributions to this repo evolve the template that others clone and adopt.

## Nature of this repository

This is a documentation-heavy, code-light repository. Most files are markdown or configuration. Shell scripts implement lifecycle hooks. No source code beyond illustrative examples.

Read [`docs/CONSTITUTION.md`](./docs/CONSTITUTION.md) for the full philosophy, principles, and boundaries of this project.

## Tech stack

- **Documentation:** Markdown
- **Shell scripts:** Bash (POSIX-compatible where possible)
- **Config:** JSON (`.claude/settings.json`)
- **Diagrams:** Mermaid (renders natively on GitHub)
- **Optional adopter tools tested against:** Repomix, Ponytail, OpenSpec, Superpowers

## Build, test, lint

No build. No test suite. No linter. This is a template repository.

Contributions are validated by:

- Manual review against `CONTRIBUTING.md` checklist
- Cross-checking directory tree in `README.md` against actual filesystem
- Testing shell scripts standalone (see `CONTRIBUTING.md`)
- Verifying internal links resolve

```bash
# Verify shell scripts run without syntax errors
bash -n .claude/hooks/*.sh
bash -n .claude/scripts/*.sh

# Verify JSON is valid
python3 -m json.tool .claude/settings.json > /dev/null && echo "settings.json valid"

# List all skill and agent files to spot missing pieces
find .claude/skills -name "SKILL.md" | sort
find .claude/agents -name "*.md" | sort
```

## Structure

- `.claude/` Claude Code configuration (skills, agents, hooks, rules, docs, scripts, context)
- `.github/` GitHub-facing files (issue templates, PR template, Copilot instructions)
- `docs/` human-facing project documentation
- `specs/` example spec-driven artifacts (with `0000-example-feature/` as reference)
- `src/example-module/` shows the nested CLAUDE.md pattern
- Root: cross-tool config (`AGENTS.md`, `CLAUDE.md`, `ECOSYSTEM.md`) and standard docs (`README.md`, `LEARN.md`, `CONTRIBUTING.md`, `CHANGELOG.md`, `LICENSE`)

See the tree diagram in `README.md` for the complete layout.

## Conventions

Applied both to the template's own content and recommended for adopters:

- English for all documentation
- Markdown for all files (no MDX, no preprocessing)
- No em-dashes in copy
- One H1 per file, used as the title
- Code blocks have language tags
- File paths in inline code with backticks
- Directory paths end with slash (`docs/`, not `docs`)
- Dates in ISO format (`YYYY-MM-DD`)

## Feature workflow

Even though this repo has no application code, feature additions to the template itself follow the same spec-driven flow that the template teaches:

1. Discuss the change in an issue or discussion
2. Optionally write `specs/YYYY-MM-DD-<slug>/spec.md` for larger changes
3. Optionally break into `plan.md` (architecture) and `tasks.md` (atomic steps)
4. Implement changes, updating relevant files
5. Update `README.md` tree, `CHANGELOG.md`, and any affected docs
6. Open PR referencing the spec or issue

For small changes (typo fix, single doc improvement), skip the spec and open the PR directly.

## Before writing new code

For this repo specifically, "new code" almost always means new markdown or shell scripts:

- Search for existing similar files (`grep`, `find`)
- Look for related patterns in `docs/patterns/` and `LEARN.md`
- Check the tree diagram in `README.md` to see if the location already exists
- Prefer extending existing skills or agents over creating parallel ones
- If creating a new skill, subagent, hook, or rule, follow the "Adding a new..." sections in `CONTRIBUTING.md`

## Where to look

| Need | Place |
|---|---|
| Constitution and philosophy | `docs/CONSTITUTION.md` |
| Guided course through the structure | `LEARN.md` |
| Contribution rules and checklists | `CONTRIBUTING.md` |
| Version history | `CHANGELOG.md` |
| Adoption walkthrough | `docs/guides/initial-setup.md` |
| Recommended external tools | `README.md` section "Recommended ecosystem" |
| Architecture decision records | `docs/decisions/` |

## Non-negotiables

Documented in full in `docs/CONSTITUTION.md`. The short version:

- **Stack agnosticism.** No file may assume a specific framework, database, or vendor. Placeholders and examples only.
- **Cross-tool compatibility.** Every workflow must be executable by any AGENTS.md-compatible agent.
- **Documentation over code.** Structural decisions are described, not implemented.
- **Attribution preserved.** Community contributions keep their author attribution inline.
- **Context economy.** What loads always must be small. What is detailed must load on demand.

## Files agents should not touch

- `.env*` and any file matching `**/secrets/**` (blocked by `block-secrets.sh` hook)
- `node_modules/` (if any adopter creates it locally)
- `CLAUDE.local.md` and `.claude/settings.local.json` (personal, gitignored)
- `.claude/agent-memory/` (per-subagent memory, gitignored)
- `.claude/context/` (Repomix snapshot and generated state, gitignored)
- Applied migrations, lockfiles, generated code (blocked by `protect-critical.sh` hook)

## More context

- [`README.md`](./README.md) human entry point with tree, layers, brownfield, ecosystem
- [`LEARN.md`](./LEARN.md) 12-chapter guided course
- [`CONTRIBUTING.md`](./CONTRIBUTING.md) how to contribute without breaking teaching value
- [`docs/CONSTITUTION.md`](./docs/CONSTITUTION.md) project DNA
- [`docs/guides/initial-setup.md`](./docs/guides/initial-setup.md) adoption walkthrough
- [`CHANGELOG.md`](./CHANGELOG.md) release history
