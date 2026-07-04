# Domain Documentation Maintenance Checklist

Use this when code changes after a local domain doc already exists.

## Update workflow

1. Read existing domain doc first.
2. Inspect current diff and current code under the domain root.
3. Classify each change:
   - durable domain rule;
   - internal responsibility change;
   - external wrapper/consumer detail;
   - transient implementation detail;
   - verification-only change.
4. Translate existing non-English domain docs to English while preserving durable meaning.
5. Update only durable domain rules and internal responsibility changes.
6. Remove obsolete or contradicted guidance.
7. Re-run validation gate.

## Diff review prompts

Ask these questions:

- Did the public export surface change?
- Did a new internal layer appear?
- Did model shape or normalized contract change?
- Did an invariant, fallback, validation, or compatibility rule change?
- Did side-effect ownership move between pure core, hooks, actions, UI, or adapters?
- Did external consumer details leak into the doc?
- Does any sentence depend on temporary specs/plans or commit history?
- Is the generated domain doc fully English, without mixed-language headings or body text?
- Does each bullet describe WHAT the domain does, not WHERE code lives or HOW to maintain it?
- Did the doc add function/file rosters, UI render narration, or condition lists that duplicate code? Strip them to the durable rule.
- Did the doc add meta sections (Design decisions, When changing, Anti-patterns)? Remove unless a line is non-obvious and not already an invariant.

## Edit discipline

- Prefer small patches over rewriting the whole doc.
- Preserve accurate existing domain knowledge.
- Delete superseded rules; do not keep “old behavior” unless current code still supports it.
- Keep the document self-contained enough to survive branch cleanup.
- Keep examples minimal and stable.

## Validation commands

Use equivalent tools for the environment:

```bash
wc -l path/to/CLAUDE.md
rg -n "docs/superpowers|specs?/|plans?/|implementation[- ]plan|pnpm|npm run|npm test|vitest|jest|CI|coverage|commit [a-f0-9]{7,}|PR #|rollout|TODO|TBD" path/to/CLAUDE.md
```

Interpret matches manually. Some terms may be legitimate if the user explicitly requested them, but default is to remove transient content.

## Completion evidence

Report:

- doc path changed;
- durable changes captured;
- transient/external details intentionally excluded;
- validation checks run and results;
- any remaining ambiguity requiring user decision.
