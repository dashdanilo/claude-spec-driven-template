---
name: analyze-codebase
description: Runs once when adopting the template on an existing project. Detects tech stack, architectural patterns, and conventions, then generates initial documentation (CONSTITUTION.md, architecture overview, conventions, patterns) and a repo map. Use when the user says something like "analyze this project", "onboard me", "set up this template on an existing codebase", or when adopting the template for the first time.
disable-model-invocation: true
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

Run `find src -type f 2>/dev/null | wc -l` (or the language equivalent - `find app src lib -type f`). Record the count for the report; it no longer gates anything below, since the repo map generated in step 4 fits regardless of size.

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

### 4. Generate the repo map

Always, regardless of file count, unlike the old Repomix snapshot this replaced (see `docs/decisions/0003-repo-map-over-snapshot.md`) - it grows with directory count, not file content, so it fits on every repo size measured so far:

```bash
.claude/scripts/harness/repo-map.sh --output .claude/context/repo-map.md
```

This is the artifact `codebase-explorer` uses for panoramic context going
forward. Do not also generate a Repomix snapshot here - that mechanism is
manual/opt-in now, via the `refresh-snapshot` skill, only when a user
explicitly asks for a single-file export.

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

### 6b. Check for `script/setup` / `script/test`

Look for an executable `script/setup` and `script/test` at the repo root (the Scripts to Rule Them All convention — `docs/guides/script-setup-and-test.md`). If either is missing, note it as a recommendation in the report (step 8) — do not create them yourself. They are project-owned: only the team knows what "ready to work in" and "verified" mean for this repo.

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
- .claude/context/repo-map.md

### Updated
- CLAUDE.md (tech stack section)
- AGENTS.md (tech stack section)

### Needs your review
- Any TODO markers left in generated files
- CONVENTIONS.md (I inferred these from N files; confirm they match team intent)
- [if applicable] This repo has no `script/setup` / `script/test` (Scripts to Rule Them All). Recommended — see `docs/guides/script-setup-and-test.md` — but not created here.

### Suggested next steps
- Review the generated docs and correct anything wrong
- Commit these files as the baseline
```

## What NOT to do

- Do not run this if `.claude/context/last-analyze.log` already exists, without asking first
- Do not overwrite hand-written docs (`README.md`, `CONTRIBUTING.md`, existing `ARCHITECTURE.md`); read and reference them
- Do not invent conventions the codebase doesn't show
- Do not skip the repo map step regardless of project size - it is what `codebase-explorer` uses, and it is cheap precisely because it never depends on how many files exist
- Do not generate a Repomix snapshot here. That is a separate, manual, opt-in export (`refresh-snapshot` skill) for when a user explicitly asks for one - not part of this flow
- Do not commit `.claude/context/repo-map.md` (it's in `.gitignore`; regenerate it instead of trusting a stale copy)
