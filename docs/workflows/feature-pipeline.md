# Pipeline de feature

O caminho de ponta a ponta de uma ideia até uma PR aberta: o fluxo guiado por
spec, agentes especialistas, o gate `verify-before-done`, e um worktree por
feature. **Autônomo supervisionado** (dirija passo a passo, ou entregue o
loop ao comando `/orchestrate` para percorrer `tasks.md` por conta própria,
parando em qualquer gate vermelho).

> **Espinha dorsal portátil.** O pipeline (spec → worktree → implementar →
> gate → review → PR) é agnóstico de stack. Um **plugin de stack** preenche
> os agentes especialistas e os comandos exatos de build/test;
> `verify-before-done` descobre esses comandos a partir do `AGENTS.md`.

## Agentes e responsabilidades

| Agente | Faz |
|---|---|
| `codebase-explorer` | reconhecimento somente leitura antes de escrever uma spec |
| `spec-reviewer` | audita `spec.md` antes de ele se tornar plan/tasks |
| especialistas de stack (de um plugin) | implementam a mudança na própria camada (ex.: dados / API / UI) |
| `tester` | escreve e executa testes, descobre o framework |
| `code-reviewer` | revisa contra a spec/plan/tasks ativos (por cluster sob o `/orchestrate`, por fase quando trabalhado manualmente) |
| `reviewer` | revisão da branch inteira, executa o gate, abre a PR |

## Pipeline

```
0. explore ─▶ 1. write-spec ─▶ 2. spec-reviewer ═╗ (spec gate)
                                                 ▼
3. spec-worktree (branch from main/develop)
                                                 ▼
   ┌───────────────── loop over tasks.md ───────────────────┐
   │ 4. implement next unchecked task (stack specialist)    │
   │ 5. GATE verify-before-done  ── red ──▶ fix, back to 4  │
   │ 6. tester: tests for the area ── red ─▶ fix, back to 4 │
   │ 7. code-reviewer            ── blocking ─▶ back to 4   │
   │ 8. check the box ─▶ more tasks? back to 4              │
   └────────────────────────────────────────────────────────┘
                                                 ▼
9. reviewer: whole-branch review + gate ─▶ opens PR
10. human merges (protect-main blocks direct merge) ─▶ cleanup worktree
```

## Gates (precisam estar verdes para avançar)

1. **Gate de spec** (`spec-reviewer` aprova `spec.md`: escopo, clareza,
   fora-de-escopo). O `write-spec` o executa automaticamente.
2. **Gate de build** (`verify-before-done` verde: install → codegen →
   typecheck → build → tests, descoberto a partir do `AGENTS.md`).
3. **Gate de teste** (os testes do repositório verdes para a área tocada, via `tester`).
4. **Gate de review** (`code-reviewer`, automático por cluster sob o
   `/orchestrate`, por fase quando trabalhado manualmente, e `reviewer`,
   da branch, não têm nenhum achado bloqueante).

Um gate vermelho nunca avança. O loop corrige a causa raiz e roda de novo.
**O pipeline termina numa PR aberta, nunca em auto-merge**
(`protect-main` bloqueia merges diretos em branches protegidas).

## Variantes

- **Feature completa** (todos os passos: explore → spec → worktree → loop → PR).
- **Correção rápida** (pula a spec: branch → reproduzir o bug como um teste
  falhando via `tester` → corrigir → gates de build + test → `reviewer` → PR).
- **Só docs** (pula os gates de build/test; `reviewer` verifica a correção
  dos docs, depois PR).

## O loop (supervisionado, e autônomo)

- **Supervisionado (`/loop`):** `/loop implement the next unchecked task in specs/<slug>/tasks.md; run verify-before-done; if green check the box, else fix and retry` (uma tarefa por passagem).
- **Orquestrado (`/orchestrate <spec folder>`):** o comando reconcilia
  `tasks.md` contra o código, classifica cada tarefa para escolher seus
  gates, planeja ondas, depois roda **uma onda por vez** (a onda inteira
  despachada numa única mensagem para os especialistas de stack, coletada,
  construída e testada uma vez com `verify-before-done` + `tester`, depois
  `code-reviewer` **uma vez por cluster**, escopado aos arquivos daquele
  cluster, checkboxes marcados, próxima onda), interrompendo num gate
  vermelho ou em qualquer coisa ambígua.

## Não negociáveis

- Nunca faça commit numa branch protegida (crie uma branch `<type>/<slug>` e abra uma PR).
- Não avance um gate vermelho, e nunca declare "concluído" sem `verify-before-done`.
- Um worktree por feature (`spec-worktree`), compartilhado entre as tarefas da feature.
