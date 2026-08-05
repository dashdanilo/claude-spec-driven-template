---
name: analyze-codebase
description: Runs once when adopting the template on an existing project. Detects tech stack, architectural patterns, and conventions, then generates initial documentation (CONSTITUTION.md, architecture overview, conventions, patterns). Also creates a Repomix snapshot for projects with 100+ files. Use when the user says something like "analyze this project", "onboard me", "set up this template on an existing codebase", or when adopting the template for the first time.
---

# Analyze codebase

Bootstrap the AI structure on an existing (brownfield) project. Runs once at adoption. Everything you produce becomes the ground truth that later skills and agents rely on.

## When to invoke

- User just adopted this template on a project that already has code
- User asks to "analyze this project" or "generate the docs"
- The file `.claude/context/last-analyze.log` does not exist yet

If `.claude/context/last-analyze.log` exists and the user hasn't asked to re-analyze, ask before proceeding. Re-analysis overwrites generated docs.

## Steps

### 1. Detect the shape of the project

Read root-level config files to identify the stack:

- `package.json` - framework, dependencies, package manager, scripts
- `tsconfig.json` / `jsconfig.json` - TypeScript config, path aliases
- `pyproject.toml` / `requirements.txt` / `Pipfile` - Python
- `Cargo.toml` - Rust
- `go.mod` - Go
- `Gemfile` - Ruby
- `.eslintrc*`, `biome.json`, `prettier.rc*`, `.prettierrc*` - style
- `vite.config.*`, `next.config.*`, `astro.config.*`, `remix.config.*`, `nuxt.config.*` - bundlers and meta-frameworks
- `docker-compose.yml`, `Dockerfile` - deployment
- `.github/workflows/` - CI

If several apply (monorepo), note it and analyze the largest package first.

### 2. Count files in source directories

Run `find src -type f 2>/dev/null | wc -l` (or the language equivalent - `find app src lib -type f`).

Record the count. If ≥ 100 files, proceed with Repomix snapshot in step 4. If < 100, skip Repomix.

### 3. Sample source files to infer conventions

Pick 10-15 representative files across different categories:

- 3-5 components
- 2-3 hooks/composables (if applicable)
- 2-3 utilities
- 1-2 API routes or server handlers
- 1-2 test files

For each, read the file and extract:

- Named vs default exports
- Absolute vs relative imports (does the project use `@/*` alias?)
- Barrel files (`index.ts` re-exporting)
- `import type` used separately or inline
- File naming convention (kebab-case, PascalCase, camelCase)
- Where tests live (co-located, `__tests__/`, separate `tests/`)

### 4. Generate Repomix snapshot (if applicable)

Only if the file count from step 2 is ≥ 100 (threshold configurable in `.claude/context/config.json`).

Repomix v1.16+ requires Node 20+. On Node 18 the command runs but yields an empty snapshot, so verify the version first:

```bash
node_major=$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null)
if [ "${node_major:-0}" -lt 20 ]; then
  echo "Node ${node_major} detected. Repomix needs Node 20+; skipping snapshot until Node is upgraded."
fi
```

Run: `npx repomix --output .claude/context/repomix-snapshot.md.tmp`

Then prepend the metadata header:

```bash
current_commit=$(git rev-parse HEAD)
current_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
files_count=$(grep -c "^## File:" .claude/context/repomix-snapshot.md.tmp || echo "?")

cat > .claude/context/repomix-snapshot.md <<EOF
# Repomix snapshot

generated_at: $current_date
commit_sha: $current_commit
branch: $(git branch --show-current)
files_captured: $files_count

---

EOF
cat .claude/context/repomix-snapshot.md.tmp >> .claude/context/repomix-snapshot.md
rm .claude/context/repomix-snapshot.md.tmp
```

### 5. Generate the documentation

Create the following files. Where content is inferred from the codebase, be specific. Where uncertain, leave `TODO` markers.

- `docs/CONSTITUTION.md` - project DNA: what it does, who uses it, non-negotiable principles, scope boundaries
- `docs/architecture/overview.md` - components diagram, trust model, main data flows
- `docs/CONVENTIONS.md` - inferred conventions from step 3
- `docs/patterns/README.md` - set up the folder structure with a template for adding new patterns

Reuse existing files if they exist (`README.md`, `ARCHITECTURE.md`, `CONTRIBUTING.md` in the repo). Don't overwrite; incorporate.

### 6. Update the AI-facing files

- Update `CLAUDE.md` to reflect the detected stack (replacing placeholders)
- Update `AGENTS.md` to reflect the same
- Do NOT invent conventions. If unclear, leave placeholders and note it in your final report.

### 7. Log the run

```bash
mkdir -p .claude/context
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) - analyze-codebase completed" > .claude/context/last-analyze.log
```

### 8. Report

Summarize what you did and what needs human review:

```
## analyze-codebase complete

### Generated
- docs/CONSTITUTION.md
- docs/architecture/overview.md
- docs/CONVENTIONS.md
- docs/patterns/README.md
- .claude/context/repomix-snapshot.md (if applicable)

### Updated
- CLAUDE.md (tech stack section)
- AGENTS.md (tech stack section)

### Needs your review
- Any TODO markers left in generated files
- CONVENTIONS.md (I inferred these from N files; confirm they match team intent)

### Suggested next steps
- Review the generated docs and correct anything wrong
- Commit these files as the baseline
```

## What NOT to do

- Do not run this if `.claude/context/last-analyze.log` already exists, without asking first
- Do not overwrite hand-written docs (`README.md`, `CONTRIBUTING.md`, existing `ARCHITECTURE.md`); read and reference them
- Do not invent conventions the codebase doesn't show
- Do not skip the Repomix step for large projects (100+ files) - the codebase-explorer needs it
- Do not commit `.claude/context/repomix-snapshot.md` (it's in `.gitignore`)
