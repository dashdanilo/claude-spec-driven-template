# Adopting on an existing codebase

> Moved out of `README.md` to keep the front door short. Linked from there.

## Preparing for brownfield

Most projects are not built from scratch. If you're adopting this template on a codebase that already exists, the challenge is different: the agent needs to **understand what's already there** before it starts creating things. Left alone, agents treat every codebase as greenfield and confidently introduce parallel implementations of things that already exist.

This template ships six practices to counter that:

**1. `analyze-codebase` skill (one-time setup)**
Detects the tech stack, samples files to infer conventions, and generates `docs/CONSTITUTION.md`, `docs/architecture/overview.md`, `docs/CONVENTIONS.md`. For projects with 100+ files in `src/`, also generates a Repomix snapshot at `.claude/context/repomix-snapshot.md`.

**2. Repomix snapshot (panoramic context)**
[Repomix](https://github.com/yamadashy/repomix) packs the entire codebase into a single file that subagents read in isolated context. The `check-snapshot.sh` script classifies the snapshot as `fresh`, `stale-mild`, or `stale-major`. The `codebase-explorer` subagent refreshes automatically when stale-major. A `SessionStart` hook warns you when the snapshot is stale.

**3. `codebase-explorer` subagent (deep read)**
Read-only archaeology. Investigates the codebase, cross-references docs, returns findings without polluting the main context. Uses the snapshot when it's fresh; refreshes it when it's not.

**4. `find-existing-first` skill (reuse before create)**
Fires immediately before creating any new file. Searches synonyms, checks patterns, reports findings. Only proceeds to creation if nothing suitable exists.

**5. `explore` skill (think before spec)**
Free-form investigation and discussion before writing a spec. Reads the docs and codebase, weighs options, discusses tradeoffs. No files are created during exploration.

**6. Optional: Ponytail plugin (project-agnostic)**
[Ponytail](https://github.com/DietrichGebert/ponytail) is a cross-tool plugin that applies a YAGNI ladder before writing any code. Complements the template's own skills.

### Adoption workflow on an existing project

```
1. Clone the template into the project
2. Run /skill analyze-codebase (generates docs/ baseline)
3. Review the generated docs and commit as baseline
4. Optional: install Ponytail plugin
5. Start using explore + write-spec for new features
```

The `codebase-explorer` subagent and the snapshot machinery run silently after that. You don't manage them.

---
