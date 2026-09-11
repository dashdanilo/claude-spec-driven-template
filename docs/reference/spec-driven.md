# The spec-driven layer

> Moved out of `README.md` to keep the front door short. Linked from there.

## Spec-driven layer

### [`specs/`](./specs/)

The spec-driven development pattern, popularized by the Superpowers plugin. Each feature lives in its own folder:

```
specs/YYYY-MM-DD-feature-slug/
├─ spec.md       # WHAT to build, source of truth
└─ plan.md       # HOW to build, broken into 2-5min TDD tasks
```

The flow:

```mermaid
flowchart TD
    A["User has an idea"] --> B["/skill explore"]
    B --> C{"Idea clear?"}
    C -->|"No, keep discussing"| B
    C -->|Yes| D["/skill write-spec"]
    D --> E["specs/YYYY-MM-DD-slug/spec.md"]
    E --> F["spec-reviewer subagent audits"]
    F --> G{"Spec approved?"}
    G -->|"Needs work"| E
    G -->|Yes| H["Fill plan.md<br/>architecture, tech, phases"]
    H --> I["Fill tasks.md<br/>atomic TDD checkboxes"]
    I --> J["Execute task N"]
    J --> K["Red: failing test"]
    K --> L["Green: minimal code"]
    L --> M["Refactor if needed"]
    M --> N["code-reviewer subagent<br/>auto-gates each phase"]
    N --> O{"Approved?"}
    O -->|"Needs changes"| J
    O -->|"Yes, check box in tasks.md"| P{"More tasks?"}
    P -->|Yes| J
    P -->|No| Q["Merge"]

    style E fill:#dbeafe,stroke:#2563eb
    style H fill:#dbeafe,stroke:#2563eb
    style I fill:#dbeafe,stroke:#2563eb
    style F fill:#fef3c7,stroke:#d97706
    style N fill:#fef3c7,stroke:#d97706
    style Q fill:#dcfce7,stroke:#16a34a
```

This diagram shows the flow worked task by task, by hand — `code-reviewer` gates each phase. Driven by `/orchestrate` instead, the same gate runs once per cluster (a group of related tasks dispatched together), not once per phase.

When code and spec diverge, the spec wins. Code gets fixed.

The `write-spec` skill ships the `spec.md` / `plan.md` / `tasks.md` templates in [`baseline/skills/write-spec/references/`](./baseline/skills/write-spec/references/) and copies them into `specs/YYYY-MM-DD-<slug>/` for you.

---
