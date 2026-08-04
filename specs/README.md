# specs/

Spec-driven development artifacts. Each feature lives in its own folder with three files that separate WHAT, HOW (strategy), and HOW (execution).

## Folder layout

```
specs/
└── YYYY-MM-DD-feature-slug/
    ├── spec.md        # WHAT + WHY (source of truth)
    ├── plan.md        # HOW at high level (architecture, tech choices, phases)
    ├── tasks.md       # HOW at execution level (atomic checkboxes, TDD)
    ├── lessons.md     # what broke → the fix          (created on demand)
    └── deviations.md  # where execution left the plan (created on demand)
```

The date prefix keeps features ordered chronologically. The slug is short kebab-case (max 5 words).

The first three are written before execution. The last two are **written during it** and only exist if something happened — `write-spec` does not scaffold them, and an absent file is the honest state.

## Why three files instead of one

Each file has a different purpose, audience, and update rate:

| File | Purpose | Updates | Read by |
|---|---|---|---|
| `spec.md` | WHAT to build and WHY | Rarely, only if the feature changes | `spec-reviewer`, human reviewers |
| `plan.md` | HOW: architecture, tech, phases | Occasionally, if approach changes | `code-reviewer` for context, human reviewers |
| `tasks.md` | Atomic checkboxes with TDD steps | Constantly during execution | `code-reviewer` for progress, agents doing work |
| `lessons.md` | What broke and how it was fixed | On every failure+fix | `/status`, `/handover`, whoever promotes a lesson to a rule |
| `deviations.md` | Where execution left the agreed plan, and why | On every departure | `/handover` (open decisions), `spec-reviewer`, human reviewers |

`lessons.md` and `deviations.md` are both execution logs and they answer different questions. A lesson is *"this broke, here is the fix"* — it is about the **system**, and if the same class shows up 3+ times it gets promoted to a `.claude/rules/` rule. A deviation is *"we agreed X and did Y"* — it is about **this feature's plan**, and it never gets promoted; it gets read, accepted or reverted, and closed.

Keeping them apart matters because a deviation with nowhere to go ends up written **inside the artifact it contaminated**: phases executed straight from `plan.md` without becoming tasks, or a whole block built on a premise nobody checked, get narrated in `tasks.md` as prose competing with the checkboxes. That is how a task file turns into a state dump.

If you collapse them:
- Merging spec into plan mixes "what to build" with "how to build"
- Merging plan into tasks mixes strategy with execution details
- Merging all three creates a long file where finding "where did I stop?" is painful

Kept separate:
- `tasks.md` is the answer to "where did I stop?" (first unchecked box)
- `plan.md` is the answer to "why this architecture?" (once, at planning time)
- `spec.md` is the answer to "what are we building?" (imutable after approval)

## The workflow

```
1. /skill explore             ← discuss, no files yet
2. /skill write-spec           ← creates spec.md (filled) + plan.md + tasks.md (scaffolds)
3. spec-reviewer subagent      ← audits spec.md (mandatory — write-spec auto-runs it)
4. You fill plan.md            ← architecture, tech choices, phases
5. You (or writing-plans) fill tasks.md   ← atomic TDD checkboxes
6. /skill spec-worktree        ← (optional) isolate the feature in its own worktree
7. Execute task by task        ← check boxes, add inline Notes when useful
8. code-reviewer subagent      ← auto-gates each phase (no permission), reports a verdict
9. Ship                        ← spec status → Done
```

Step 6 is optional but recommended when working several features in parallel: one worktree **per feature** (a flat sibling `../<repo>.<slug>` on branch `<type>/<slug>` from `main`), shared across all of that feature's plans. See the "Worktrees" section in `.claude/rules/git-workflow.md`.

## The templates

The `spec.md`, `plan.md`, and `tasks.md` templates are the single source of truth, shipped inside the `write-spec` skill at `.claude/skills/write-spec/references/`. Running `write-spec` copies them into `specs/YYYY-MM-DD-<slug>/` and fills the headers. You can also copy them by hand and rename.

## Interop

The three-file structure is compatible with:

- **[Superpowers](https://github.com/obra/superpowers):** `writing-plans` skill generates `plan.md` and `tasks.md` (in some versions inline in one file, in newer versions split)
- **[OpenSpec](https://github.com/Fission-AI/OpenSpec):** point OpenSpec to `specs/` in its config
- **[Spec Kit](https://github.com/github/spec-kit):** uses `spec.md`, `plan.md`, `tasks.md` natively
- **Manual:** any agent can read markdown and follow the pattern

When code and spec diverge, the spec wins. Stop and ask.
