---
name: documenting-domains
description: >-
  Use when creating or maintaining concise local domain documentation such as nested CLAUDE.md
  files for a feature, bounded context, module, package, or subsystem that needs durable
  agent-facing knowledge after temporary specs/plans are removed, or after behavior, invariants,
  adapters, exports, or ownership boundaries change.
---

# Documenting Domains

> **Attribution:** Original skill by [douglasgomes98](https://github.com/douglasgomes98). Included in this template with permission and light adaptation.

Create durable, local domain documentation that future agents can use without re-reading temporary specs, plans, commits, or broad implementation history.

## Core rule

Document stable domain knowledge, not the work session that produced it.

Discriminate **behavior vs structure**: document WHAT the domain does and why (model, invariants, behavior rules, contracts). Cut WHERE code lives and HOW to maintain it (file/function rosters, render narration, hygiene rules, process meta).

Prefer local `CLAUDE.md` when the knowledge is scoped to one directory and should load when agents work there. Use skills for reusable workflows; use hooks/settings for enforcement.

## Workflow

Copy this checklist and track progress:

```text
Domain Documentation Progress:
- [ ] Define domain boundary and intended reader
- [ ] Research code, tests, docs, and recent diffs for durable behavior
- [ ] Separate internal domain facts from external consumer details
- [ ] Draft concise local documentation
- [ ] Validate size, scope, staleness, and references
- [ ] Update only durable facts when maintaining existing docs
```

## Research first

Read [references/research-checklist.md](references/research-checklist.md) before writing. Identify:

- public entrypoints and exports;
- internal responsibility map;
- normalized models and contracts;
- invariants and compatibility rules;
- state, selection, validation, pricing, side effects, or adapters;
- boundaries: what belongs inside the domain vs wrappers/consumers.

## Write the document

Use [references/domain-doc-template.md](references/domain-doc-template.md) as default shape. Keep it concise enough to fit the local context budget:

- write generated domain documentation in English, even if the user conversation or existing draft uses another language;
- target under 200 lines;
- headers + bullets over prose;
- concrete rules over vague guidance;
- stable concepts over implementation trivia;
- internal contracts over external consumer internals.
- responsibilities grouped by stable layer/contract, not every file, unless a file is a public entrypoint or durable boundary.
- no function-name or file-path rosters - state the rule, not the function list that implements it;
- no UI render narration - document integration contracts (callbacks, props), not what a component renders;
- no condition lists that duplicate validation/selection code - summarize the rule and its scope;
- omit process meta and code hygiene (e.g. "update this file when X", "keep core pure", "do not put Y in Z").

## Maintain existing docs

Use [references/maintenance-checklist.md](references/maintenance-checklist.md) when updating domain documentation after code changes.

Update docs when durable behavior changes: model shape, domain invariants, exports, adapters, action semantics, validation rules, ownership boundaries, or anti-patterns.

Do not update docs for pure formatting, temporary rollout notes, one-off debugging findings, or verification commands.

## Exclude

- Temporary specs/plans, unless the user explicitly wants a reference and it will survive branch cleanup.
- Commit history, PR narrative, migration diary, or “how we got here”.
- Test files, test cases, coverage narratives, test commands, lint/build commands, CI status, or verification output.
- Exhaustive file-by-file summaries that duplicate the tree.
- Framework or language tutorials the agent already knows.
- External consumer details beyond stable contracts and boundaries.
- TODO/TBD placeholders.
- Mixed-language headings/body in generated domain docs.

## Validation gate

Before reporting completion:

1. Count lines; keep local `CLAUDE.md` under 200 lines unless user approves more.
2. Search for forbidden transient content: specs/plans paths, commands, commits, TODO/TBD, unrelated consumers.
3. Re-read changed doc against current code and confirm every durable invariant has a home.
4. Verify no contradiction with parent/local instructions.

## Common mistakes

| Mistake | Fix |
|---|---|
| Documenting tests and commands | Keep verification in plans/PRs, not domain memory |
| Explaining every file | Document responsibilities and invariants |
| Including consumer internals | Keep only stable domain contracts |
| Linking disposable specs/plans | Make doc self-contained enough to survive cleanup |
| Keeping obsolete rules | Remove superseded behavior during maintenance |
| Mirroring user language | Write generated domain docs in English |
| Function/file rosters, render narration | State the behavior rule; don't list functions or UI internals |
| Meta sections (Design decisions, When changing, Anti-patterns) | Omit by default; they collect hygiene and restate invariants |

## References

- Default CLAUDE.md shape: [references/domain-doc-template.md](references/domain-doc-template.md)
- Research workflow: [references/research-checklist.md](references/research-checklist.md)
- Update workflow: [references/maintenance-checklist.md](references/maintenance-checklist.md)
