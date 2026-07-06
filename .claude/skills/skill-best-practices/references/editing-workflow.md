# Editing Workflow

Use this reference when modifying, refactoring, splitting, merging, renaming, or deleting an existing skill. Creation-only tasks use the main SKILL.md Creation Workflow instead.

## E0. Conflict + cross-reference scan

Before touching any file:

```bash
# Find all references to the skill being changed
git grep -nE 'skills/<name>|\.agents/skills/<name>' -- '*.md'
```

Read every `SKILL.md` that might overlap with the change. List any contradictions and resolve them before writing.

## E1. Capture a preservation list

In the PR description, list the items that must survive the edit:

- Commands that must survive verbatim
- Annotated examples (WRONG/CORRECT, ✓/✗) that encode institutional knowledge
- Anti-patterns that are still relevant
- Cross-reference paths that exist in other skills or `agents/*.md`

**Rule:** Do not delete refined examples without an entry in the preservation list explaining why.

## E2. Decide the shape change

| Signal | Action |
|---|---|
| Two skills duplicate > 60% of steps and only diverge in commands | Unify with explicit columns (model: `security-audit-release` post-dedup) |
| One skill mixes two distinct CI gates or release artifacts | Branch with explicit columns inside one SKILL.md |
| SKILL.md references are growing > 200 lines and cover unrelated topics | Split references; keep SKILL.md intact |
| A reference is consulted from more than one skill | Promote to its own skill OR keep in origin and add a cross-link |
| Skill behavior no longer applies or is superseded | Delete the entire skill; update all cross-references (Rule 7) |

## E3. Apply the edit

- Keep description key terms. If you must change them, document old → new in the PR body so consumers can update their agent configurations.
- Move detailed flow rules to `references/`, not delete them.
- For any multi-skill refactor that touches > 1 skill or moves content across `references/`, write an inventory + parity matrix in the PR description before editing. The inventory lists every behavior, command, and example that must be preserved (or explicitly removed with rationale); the matrix lists outcomes/steps/commands/artifacts/CI gates per repo type.

## E4. Update cross-references

After renaming or removing a skill:

```bash
git grep -nE 'skills/<old-name>|\.agents/skills/<old-name>'
```

Update every hit, including:
- `agents/*.md`
- `README.md`
- Other `skills/*/SKILL.md` and `references/*.md`

When a skill is removed or renamed, list the old → new mapping in the PR description so consumer repos know what to update.

## E5. Editing validation checklist

- [ ] Every behavior in the preservation list still has a home (SKILL.md or referenced file)
- [ ] No broken cross-references (`git grep` returns no hits for old paths)
- [ ] Description still contains the original trigger terms, or PR body documents each change
- [ ] No reference file > 200 lines
- [ ] SKILL.md still < 200 lines
- [ ] Behavior intentionally removed: each removal listed in the PR body with rationale
- [ ] Anti-pattern entries that no longer apply are deleted (Rule 7), not silently kept
- [ ] Submodule pointer bumped in all consumer repos after merge
