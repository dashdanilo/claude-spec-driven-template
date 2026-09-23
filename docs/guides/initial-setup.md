# Initial setup: adopting this template

Step-by-step walkthrough for using the template on a new or existing project. Read this once before you start.

## Prerequisites

- Git (any recent version), Bash, and Python 3 (all standard on any dev machine; the repo map and the harness's own checks use only these)
- Node.js 20+, optional: only needed if you use the manual `refresh-snapshot` skill (Repomix v1.16+ requires Node 20; older Node produces an empty export)
- At least one AI coding agent installed. Claude Code recommended, but the template works with Codex, Cursor, Copilot, and Gemini too.

## Path 1: New project (greenfield)

You're starting a project from scratch.

### 1. Create the repo from the template

If browsing on GitHub:

1. Click "Use this template" > "Create a new repository"
2. Name it, pick visibility, click Create

If cloning locally:

```bash
git clone https://github.com/dashdanilo/claude-spec-driven-template my-project
cd my-project
rm -rf .git
git init
```

### 2. Personalize AGENTS.md (source of truth)

Open `AGENTS.md`. Replace:

- Project name at the top
- Tech stack section with your actual stack
- Build/test/lint commands with the actual commands
- Structure section with your actual folder layout
- Conventions to match your team's preferences

This is the file every AI agent will read. Take your time.

### 3. Personalize CLAUDE.md (stub)

Open `CLAUDE.md`. Only update the project name at the top. The rest is auto-configured based on the skills, subagents, and hooks in `.claude/`.

### 4. Update README.md

Replace the project name and description. Keep the structural sections (they explain the template's design and are useful for contributors).

### 5. Clean up examples

Once you understand the patterns:

- Delete or replace `src/example-module/CLAUDE.md`
- Rename `.claude/skills/example-skill/` to your first real skill (or delete)
- Rename `.claude/rules/example-rule.md` to your first real rule (or delete)
- Delete `docs/decisions/0001-example.md` (replace with your first ADR)
- Delete `.claude/docs/libs/example-lib.md` when you add your first real lib doc
- Rename `docs/CONSTITUTION.md.example` to `docs/CONSTITUTION.md` and fill in

### 6. Optional: add `script/setup` and `script/test`

If your team wants one command that takes a clone (or worktree) to "ready to
work in", and one command that is the verification gate, add executable
`script/setup` and `script/test` at the repo root. The harness only *calls*
these when they exist — `spec-worktree` runs `script/setup` after creating a
worktree, and `verify-before-done` uses `script/test` as the gate instead of
guessing commands. It does not generate them for you, and a repo without them
loses nothing: the step is a no-op. See
[`docs/guides/script-setup-and-test.md`](./script-setup-and-test.md).

### 7. Commit the baseline

```bash
git add .
git commit -m "chore: adopt claude-spec-driven-template as v0.1 baseline"
```

### 8. Start using it

For your first feature:

```
/skill explore                        # discuss what to build
/skill write-spec my-first-feature    # creates specs/2026-07-04-my-first-feature/ with spec.md filled and plan.md, tasks.md scaffolded
```

Then fill in `plan.md` (architecture, tech, phases) and `tasks.md` (atomic TDD checkboxes), and start building.

---

## Path 2: Existing project (brownfield)

You already have code and want to adopt this template.

### 1. Install the scaffolding

Use the installer. Run it from inside your repo (it pulls the template fresh):

```bash
cd /path/to/your-project
curl -fsSL https://raw.githubusercontent.com/dashdanilo/claude-spec-driven-template/main/install.sh | bash
```

Or, from a local template clone, target your repo:

```bash
./install.sh --to /path/to/your-project
```

The installer copies the agent scaffolding (`.claude/`, `docs/`, `specs/`, `AGENTS.md`, `CLAUDE.md`, `ECOSYSTEM.md`, `.claudeignore`, `.github/`, `CLAUDE.local.md.example`), and:

- **Never overwrites** files that already exist in your repo - it skips and warns (use `--force` to override). Your `README.md`, `.gitignore`, and any existing `docs/` files are safe.
- **Merges** the required entries into your `.gitignore` (appends what is missing).
- Copies only git-tracked template files (no local/generated cruft) and makes the hooks executable.

Preview without writing anything using `--dry-run`.

### 2. Run `analyze-codebase` for the baseline

This is the critical step for brownfield. Open Claude Code and run:

```
/skill analyze-codebase
```

The skill will:

- Detect your tech stack from `package.json`, `tsconfig.json`, etc
- Sample representative files to infer conventions
- Generate `docs/CONSTITUTION.md`, `docs/CONVENTIONS.md`, `docs/architecture/overview.md`
- Generate a repo map at `.claude/context/repo-map.md` (always, regardless of project size)
- Update `AGENTS.md` and `CLAUDE.md` with the detected stack

### 3. Review generated docs

Look for `TODO` markers in the generated files. Those are where the analysis was uncertain. Fill them in with your knowledge.

Also review:

- The tech stack in `AGENTS.md` (may need adjustment)
- The conventions in `docs/CONVENTIONS.md` (are these really your team's conventions?)
- The architecture overview in `docs/architecture/overview.md` (does the diagram reflect reality?)

### 4. Commit the baseline

```bash
git add .
git commit -m "chore: adopt claude-spec-driven-template with generated baseline"
```

### 5. Optional: add `script/setup` and `script/test`

If your team wants one command that takes a clone (or worktree) to "ready to
work in", and one command that is the verification gate, add executable
`script/setup` and `script/test` at the repo root. The harness only *calls*
these when they exist — `spec-worktree` runs `script/setup` after creating a
worktree, and `verify-before-done` uses `script/test` as the gate instead of
guessing commands. It does not generate them for you, and a repo without them
loses nothing: the step is a no-op. See
[`docs/guides/script-setup-and-test.md`](./script-setup-and-test.md).

### 6. Optional: install recommended plugins

- [Ponytail](https://github.com/DietrichGebert/ponytail) for cross-tool YAGNI enforcement
- [Superpowers](https://github.com/obra/superpowers) for enforced spec-driven flow (Claude-only)
- [OpenSpec](https://github.com/Fission-AI/OpenSpec) for cross-tool spec workflow

### 7. First feature using the template

```
/skill explore                    # discuss what to build
/skill find-existing-first        # check if similar code exists
/skill write-spec <slug>          # create the spec
```

---

## Maintaining the template over time

### The repo map, and when you'd ever touch Repomix

The repo map regenerates fresh every time `codebase-explorer` runs. There is
nothing to refresh and nothing to think about.

The Repomix export is a different, separate thing: manual, opt-in, and only
useful if you need a single-file dump of the codebase for a tool that can't
read the filesystem itself. Most sessions never need it:

```
/skill refresh-snapshot
```

See `docs/decisions/0003-repo-map-over-snapshot.md` for why these are two
different mechanisms now instead of one.

### When to add a new subagent

When you find yourself invoking a specific pattern repeatedly ("check auth handling here", "profile this code path"). Create a subagent with a narrow role and a triggering description.

### When to add a new ADR

When someone asks "why did we do X?" more than twice. Turn the answer into an ADR in `docs/decisions/`.

### When to update `docs/CONVENTIONS.md`

When you notice code review comments repeating the same feedback. That's a convention worth documenting.

### When to update `AGENTS.md`

When the stack changes (framework upgrade, new external service, major dependency swap). Update it once, all agents see the change.

---

## Troubleshooting

### The SessionStart hook shows warnings I don't want

Edit `.claude/context/config.json` to adjust thresholds, or disable the hook by removing it from `.claude/settings.json`.

### `refresh-snapshot` seems to hang

Only relevant if you're using the manual Repomix export - `analyze-codebase` itself no longer runs Repomix at all, so it should never hang on this. The Repomix step in `refresh-snapshot` can take 30-60 seconds on large repos. If it's still going after 2 minutes, cancel and add a `.repomixignore` to reduce scope.

### Claude doesn't seem to know about the skills

Verify:

- The skill file exists at `.claude/skills/<name>/SKILL.md`
- The frontmatter has valid `name` and `description`
- The description starts with a triggering condition (`Use when...`)

Descriptions are the auto-invocation trigger, not documentation.

### Cross-tool concerns

- Codex, Cursor, Gemini read `AGENTS.md` natively (or via config)
- Copilot reads `.github/copilot-instructions.md`
- Only Claude Code reads `.claude/` - other tools ignore it

Update `AGENTS.md` for cross-tool changes. Update `CLAUDE.md` only for Claude-specific things.
