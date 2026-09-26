# A camada guiada por spec

> Movido para fora do `README.md` para manter a porta de entrada curta. Linkado a partir de lá.

## Camada guiada por spec

### [`specs/`](./specs/)

O padrão de desenvolvimento guiado por spec, popularizado pelo plugin
Superpowers. Cada feature vive na própria pasta:

```
specs/YYYY-MM-DD-feature-slug/
├─ spec.md       # O QUE construir, fonte da verdade
└─ plan.md       # COMO construir, dividido em tarefas de TDD de 2-5min
```

O fluxo:

```mermaid
flowchart TD
    A["Usuário tem uma ideia"] --> B["/skill explore"]
    B --> C{"Ideia clara?"}
    C -->|"Não, continuar discutindo"| B
    C -->|Sim| D["/skill write-spec"]
    D --> E["specs/YYYY-MM-DD-slug/spec.md"]
    E --> F["subagente spec-reviewer audita"]
    F --> G{"Spec aprovada?"}
    G -->|"Precisa de ajustes"| E
    G -->|Sim| H["Preencher plan.md<br/>arquitetura, tecnologia, fases"]
    H --> I["Preencher tasks.md<br/>checkboxes atômicos de TDD"]
    I --> J["Executar tarefa N"]
    J --> K["Vermelho: teste falhando"]
    K --> L["Verde: código mínimo"]
    L --> M["Refatorar se necessário"]
    M --> N["subagente code-reviewer<br/>gate automático a cada fase"]
    N --> O{"Aprovado?"}
    O -->|"Precisa de mudanças"| J
    O -->|"Sim, marcar checkbox em tasks.md"| P{"Mais tarefas?"}
    P -->|Sim| J
    P -->|Não| Q["Merge"]

    style E fill:#dbeafe,stroke:#2563eb
    style H fill:#dbeafe,stroke:#2563eb
    style I fill:#dbeafe,stroke:#2563eb
    style F fill:#fef3c7,stroke:#d97706
    style N fill:#fef3c7,stroke:#d97706
    style Q fill:#dcfce7,stroke:#16a34a
```

Este diagrama mostra o fluxo trabalhado tarefa por tarefa, manualmente
(o `code-reviewer` faz o gate de cada fase). Guiado pelo `/orchestrate` em
vez disso, o mesmo gate roda uma vez por cluster (um grupo de tarefas
relacionadas despachadas juntas), não uma vez por fase.

Quando código e spec divergem, a spec vence. O código é corrigido.

A skill `write-spec` traz os templates de `spec.md` / `plan.md` / `tasks.md`
em [`baseline/skills/write-spec/references/`](./baseline/skills/write-spec/references/)
e os copia para `specs/YYYY-MM-DD-<slug>/` para você.

---
