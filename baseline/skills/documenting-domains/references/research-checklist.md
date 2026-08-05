# Domain Documentation Research Checklist

Run this before drafting or updating local domain docs.

## 1. Establish boundary

- Identify domain root path.
- Identify owner entrypoints/barrels.
- List internal folders and their responsibilities.
- Decide what is out of scope: wrappers, routes, consumers, global state, tests, generated files.

## 2. Read durable sources

Prioritize current code over temporary planning artifacts:

1. Public exports and index files.
2. Model/types/contracts.
3. Pure domain logic.
4. Actions/state mutation factories.
5. Adapters/mappers.
6. Hooks/effects/integration boundaries.
7. UI/container boundaries, if owned by the domain.
8. Tests only to confirm behavior/invariants; do not document test files, test commands, coverage status, or individual test cases.

## 3. Extract facts

Capture only facts future agents cannot infer cheaply:

- invariant shape rules;
- compatibility and validation rules;
- fallback/current-selection behavior;
- side-effect ownership;
- adapters and source payload preservation;
- internal vs external boundary decisions;
- anti-patterns observed or likely.

## 4. Check external scope

External consumers belong in local domain docs only if they define stable contracts.

Use this rule:

```text
Does this detail live outside domain root?
├─ No  → document if durable
└─ Yes → document only stable contract/boundary, not implementation internals
```

## 5. Identify update triggers

Before drafting, list what should force future doc updates:

- model or token/shape changes;
- new domain-owned layer;
- changed public exports;
- changed adapter responsibility;
- changed validation/matching/selection semantics;
- moved side effects or global-state boundary;
- obsolete anti-patterns.

## 6. Conflict scan

- Read parent `CLAUDE.md`/`AGENTS.md` if present.
- Read existing nested domain docs under the same tree.
- Resolve contradictions before writing.
- If two docs disagree, ask the user or preserve the more local/current rule with explicit wording.
- If existing docs use another language, translate durable content to English instead of preserving mixed-language documentation.
