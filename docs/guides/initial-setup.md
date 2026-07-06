# Initial setup: adopting this template

Step-by-step walkthrough for using the template on a new or existing project. Read this once before you start.

## Prerequisites

- Node.js 20+ (Repomix v1.16+ requires Node 20; older Node produces an empty snapshot)
- Git (any recent version)
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

- Delete `specs/0000-example-feature/` (create your first real feature spec instead)
- Delete or replace `src/example-module/CLAUDE.md`
- Rename `.claude/skills/example-skill/` to your first real skill (or delete)
- Rename `.claude/rules/example-rule.md` to your first real rule (or delete)
- Delete `docs/decisions/0001-example.md` (replace with your first ADR)
- Delete `.claude/docs/libs/example-lib.md` when you add your first real lib doc
- Rename `docs/CONSTITUTION.md.example` to `docs/CONSTITUTION.md` and fill in

### 6. Commit the baseline

```bash
git add .
git commit -m "chore: adopt claude-spec-driven-template as v0.1 baseline"
```

### 7. Start using it

For your first feature:

```
/skill explore                        # discuss what to build
/skill write-spec my-first-feature    # creates specs/2026-07-04-my-first-feature/ with spec.md filled and plan.md, tasks.md scaffolded
```

Then fill in `plan.md` (architecture, tech, phases) and `tasks.md` (atomic TDD checkboxes), and start building.

---

## Path 2: Existing project (brownfield)

You already have code and want to adopt this template.

### 1. Copy the template into your repo

Manually copy the files, or:

```bash
# In a separate directory, clone the template
git clone https://github.com/dashdanilo/claude-spec-driven-template /tmp/template

# Copy the AI-relevant parts into your existing repo
cd /path/to/your-project
cp -r /tmp/template/.claude .
cp -r /tmp/template/docs .
cp -r /tmp/template/specs .
cp /tmp/template/AGENTS.md .
cp /tmp/template/CLAUDE.md .
cp /tmp/template/CLAUDE.local.md.example .
cp /tmp/template/ECOSYSTEM.md .
mkdir -p .github/ISSUE_TEMPLATE
cp -r /tmp/template/.github/* .github/
cp /tmp/template/.claudeignore .
cp /tmp/template/CHANGELOG.md .
```

Do NOT overwrite your existing `README.md` or `.gitignore`. Merge them manually.

### 2. Update your `.gitignore`

Add these entries:

```
# Personal Claude Code files
CLAUDE.local.md
.claude/settings.local.json
.claude/agent-memory/

# Generated context
.claude/context/repomix-snapshot.md
.claude/context/last-analyze.log
.claude/context/config.json

# Claude Code session state
.claude/projects/
.claude/shell-snapshots/
.claude/backups/
```

### 3. Run `analyze-codebase` for the baseline

This is the critical step for brownfield. Open Claude Code and run:

```
/skill analyze-codebase
```

The skill will:

- Detect your tech stack from `package.json`, `tsconfig.json`, etc
- Sample representative files to infer conventions
- Generate `docs/CONSTITUTION.md`, `docs/CONVENTIONS.md`, `docs/architecture/overview.md`
- If your project has 100+ files in `src/`, generate a Repomix snapshot at `.claude/context/repomix-snapshot.md`
- Update `AGENTS.md` and `CLAUDE.md` with the detected stack

### 4. Review generated docs

Look for `TODO` markers in the generated files. Those are where the analysis was uncertain. Fill them in with your knowledge.

Also review:

- The tech stack in `AGENTS.md` (may need adjustment)
- The conventions in `docs/CONVENTIONS.md` (are these really your team's conventions?)
- The architecture overview in `docs/architecture/overview.md` (does the diagram reflect reality?)

### 5. Commit the baseline

```bash
git add .
git commit -m "chore: adopt claude-spec-driven-template with generated baseline"
```

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

### When to refresh the Repomix snapshot

The `codebase-explorer` subagent refreshes automatically when the snapshot is stale-major (30+ files changed, 14+ days, or config file changed). You don't need to think about it usually.

Manually refresh before important sessions:

```
/skill refresh-snapshot
```

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

### `analyze-codebase` seems to hang

The Repomix step can take 30-60 seconds on large repos. If it's still going after 2 minutes, cancel and check `.claude/context/config.json` - you may want to lower the `min_files_for_snapshot` threshold or add a `.repomixignore` to reduce scope.

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
