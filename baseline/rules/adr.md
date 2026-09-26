---
paths: "docs/decisions/**"
---

# ADRs são somente para acréscimo (append-only)

Um Architecture Decision Record (ADR) é um registro histórico, não um documento vivo.

- Nunca reescreva a decisão de um ADR **aceito** (`Accepted`). Se a decisão mudar, escreva um **novo** ADR que a substitui, e marque o antigo como `Superseded by ADR-NNNN`.
- As decisões se acumulam, o rastro de por que mudamos de ideia é o valor.
- Um novo ADR declara **Context → Decision → Consequences** e um status (`Proposed` → `Accepted` → `Superseded`).
- Corrigir um erro de digitação ou adicionar um link é aceitável; mudar o que foi decidido não é.
