# Constitution

The DNA of this project. What it is, what it is not, and the non-negotiable principles that shape decisions.

Keep this file dense and stable. It should rarely change. When it does, that's a signal something fundamental shifted.

## What this project is

`claude-spec-driven-template` is a template repository for structuring AI-enabled projects around spec-driven development. It provides a reusable folder layout, agent configuration, skills, subagents, hooks, and workflow patterns that work across Claude Code, GitHub Copilot, and other AGENTS.md-compatible tools.

The template is stack-agnostic: it does not assume any specific framework, database, or language. It ships as a structural and documentation foundation to be adopted, adapted, and used as the base of real projects.

## What this project is NOT

Explicit boundaries. Things this template should never become or try to be:

- **Not an application.** There is no runtime, no server, no UI. Only documentation, configuration, and shell scripts.
- **Not opinionated about tech stack.** No preference between Next.js and Remix, Postgres and MySQL, Tailwind and CSS Modules. Adopters bring their own stack.
- **Not tied to one AI tool.** The template treats AGENTS.md as source of truth. Claude Code, Copilot, Codex, Cursor, and Gemini should all work equivalently when used with this template.
- **Not a project management framework.** It provides spec-driven structure, but no ticket tracking, no reporting, no dashboards.
- **Not a plugin.** It is a template repo, meant to be copied. Not installed, not depended upon.
- **Not a course.** LEARN.md is a guided course through the structure, but the template does not aim to teach programming, testing, or product management from scratch.

## Non-negotiable principles

These override convenience. If a proposed change violates one of these, the change gets rejected regardless of how convenient it would be.

1. **Stack agnosticism.** No file in the template may assume a specific framework, database, or vendor. Placeholders and examples only.
2. **Cross-tool compatibility.** Every documented workflow must be executable by any AGENTS.md-compatible agent, not just Claude Code.
3. **Documentation over code.** Structural decisions are documented in `docs/` and `LEARN.md`. Complex behaviors are described, not implemented.
4. **Attribution preserved.** Contributions from the community keep their author attribution inline, in perpetuity.
5. **Context economy.** What loads always must be small. What is detailed must load on demand. This principle drives the entire subsystem layering.

## Domain vocabulary

Terms specific to this template and their exact meaning:

- **Template:** the repo you are reading now. Meant to be cloned or used via GitHub "Use this template" button.
- **Adopter:** a developer or team using the template for their own project.
- **Adoption:** the act of applying the template to an existing (brownfield) or new (greenfield) project.
- **Nested CLAUDE.md:** a `CLAUDE.md` file inside `src/<folder>` that adds folder-scoped conventions.
- **Stub:** a small file whose purpose is to point to another file for its real content. `CLAUDE.md` and `.github/copilot-instructions.md` at the root are stubs pointing to `AGENTS.md`.
- **Source of truth:** the file that owns a piece of information. For project context, this is `AGENTS.md`. For a feature, this is `specs/<slug>/spec.md`.
- **Fresh, stale-mild, stale-major:** the three states classified by `.claude/scripts/check-snapshot.sh` for the Repomix snapshot.

## Tech stack (of the template itself, not of adopters)

- **Documentation format:** Markdown
- **Shell scripts:** Bash (POSIX-compatible where possible)
- **Config format:** JSON (for `.claude/settings.json`)
- **Diagram format:** Mermaid (rendered natively on GitHub)
- **AI tools tested against:** Claude Code, GitHub Copilot

## Constraints and non-goals

Hard limits that shape design:

- **Budget:** zero recurring cost. All required tools have free tiers.
- **Runtime dependencies:** none. Adopters may install optional tools (Repomix, Ponytail, OpenSpec, Superpowers), but the template functions without them.
- **Compliance:** no assumptions about GDPR, LGPD, HIPAA, or SOC2. Adopters bring their own compliance concerns.
- **Explicit non-goals:**
  - Do not evolve into a CLI tool
  - Do not evolve into an npm package
  - Do not require CI setup to be useful
  - Do not require any account, API key, or SaaS subscription

## Where the sources of truth live

- Cross-tool project context: `AGENTS.md`
- Claude-specific context: `CLAUDE.md`
- Copilot-specific context: `.github/copilot-instructions.md`
- Feature specs: `specs/YYYY-MM-DD-<slug>/`
- Architecture decisions: `docs/decisions/`
- Runbooks: `docs/runbooks/`
- Guides and tutorials: `docs/guides/`
- Living examples of solutions: `docs/patterns/`
- AI-only knowledge: `.claude/docs/`
- Change history: `CHANGELOG.md`

## Change log

Updates to this file are rare. When they happen, note them:

- 2026-07-04 - Initial constitution written alongside v0.1.0 release.
