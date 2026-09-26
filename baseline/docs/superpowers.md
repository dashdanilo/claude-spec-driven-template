# Superpowers e o fluxo spec-driven

> Última revisão: YYYY-MM-DD
> Referência: https://github.com/obra/superpowers

## O que é o Superpowers

Superpowers é um plugin oficial do Claude Code feito por Jesse Vincent (obra/superpowers). Ele instala um conjunto de skills que **impõem** um fluxo de desenvolvimento estruturado através de quality gates.

Filosofia central: agentes de IA respondem a estrutura, não a sugestões. "Sempre escreva testes primeiro" no `CLAUDE.md` é uma sugestão. Uma skill com enforcement é um gate.

## Instalação

```bash
# Inside Claude Code
/plugin install superpowers@claude-plugins-official
```

A skill `using-superpowers` carrega automaticamente via um hook SessionStart depois da instalação.

## O fluxo canônico

```
Brainstorm  →  spec.md   →  plan.md + tasks.md   →  TDD execution  →  Code review  →  Ship
   (chat)      (commit)         (commit)             (subagents)         (agent)
```

Cada gate **bloqueia** o próximo até ser resolvido.

### 1. Brainstorming

Quando você descreve uma feature, a skill `brainstorming` ativa automaticamente. O Claude NÃO escreve código. Em vez disso, ele faz perguntas socráticas até a feature ficar clara.

Saída: um documento de design apresentado em blocos para você aprovar.

### 2. Spec

Depois que o brainstorm é aprovado, ele se torna `specs/<date>-<slug>/spec.md`. Esta é a **fonte da verdade**. Qualquer divergência futura entre código e spec é resolvida lendo a spec, não o código.

### 3. Plan e tasks

A skill `writing-plans` (Superpowers) produz dois arquivos neste template:

- `plan.md` cobre o COMO de alto nível: arquitetura, escolhas técnicas, fases
- `tasks.md` cobre a execução atômica: um checkbox por tarefa, com:
  - Caminho do arquivo
  - Comandos exatos
  - Teste que falha a ser escrito primeiro
  - Código mínimo para fazê-lo passar

Nota: algumas versões mais antigas do Superpowers geram um único `plan.md` com as tarefas embutidas. Este template os separa para maior clareza. Se você usa o Superpowers como vem, configure-o para separar ou extraia as tarefas manualmente para `tasks.md` depois da geração.

### 4. Execução via subagent-driven-development

A skill `subagent-driven-development` despacha um subagente **por tarefa**, com contexto novo. Cada subagente:

1. Lê a spec (contexto)
2. Lê sua fase no plano (contexto de arquitetura)
3. Lê sua tarefa em `tasks.md` (passos de execução)
4. Escreve o teste que falha (red)
5. Implementa o mínimo para passar (green)
6. Refatora se necessário
7. Reporta de volta e marca a caixa em `tasks.md`

### 5. Code review como gate

Em cada fronteira de fase, o subagente `code-reviewer` (em `.claude/agents/`) roda automaticamente (sem prompt de permissão) e revisa contra:

- Spec
- Plan
- Convenções

Problemas CRITICAL **bloqueiam** o progresso. Sem resolução, a próxima tarefa não roda.

Essa é a cadência de fronteira de fase para trabalhar o `tasks.md` na mão. Quando o `/orchestrate` dirige o mesmo arquivo, o `code-reviewer` roda uma vez por cluster em vez disso, veja `baseline/skills/orchestrate/SKILL.md` Step 3 item 4.

### 6. Ship

A skill `finishing-a-development-branch` verifica que tudo passa, então apresenta opções: merge, PR, manter a branch, descartar.

## Como este template se integra

- **`specs/`** segue o formato de três arquivos (spec.md + plan.md + tasks.md por feature)
- **`.claude/agents/spec-reviewer.md`** complementa o brainstorming: audita a spec antes de ela se tornar um plano
- **`.claude/agents/code-reviewer.md`** age como o gate automático entre fases (entre clusters, sob `/orchestrate`)
- Arquivos aninhados **`src/<folder>/CLAUDE.md`** fornecem convenções que o code-reviewer usa

## Quando NÃO usar o fluxo completo

- **Prototipagem exploratória:** quando você ainda não sabe o que quer, prototipe sem specs. Mas o prototype NÃO se torna código de produção sem passar pelo fluxo primeiro.
- **Correção trivial de bug:** erro de digitação, ajuste de cor, atualização de label.
- **Refactor mecânico:** renomear, mover, extrair função. Sem mudança de comportamento.

Para tudo o mais: brainstorm, depois spec, depois plan, depois execução.

## Disciplina inegociável

Três coisas que, se você pular, o fluxo perde valor:

1. **Spec é fonte da verdade.** Toda pergunta "isso está certo?" é resolvida lendo a spec. Sem exceções.
2. **Teste antes de código.** Sempre. Red, green, refactor.
3. **Checkboxes de tarefa são recuperação.** Se você for interrompido, eles dizem onde você parou. Não pule.

## Erros comuns

- "Posso só implementar e escrever a spec depois?" Não. A spec captura decisões que se perdem na implementação.
- "Essa tarefa é pequena demais para uma spec." Provavelmente é uma correção trivial. Mas se você está perguntando, provavelmente não é.
- "O plano ficou enorme." Sinal de que a feature está grande demais. Divida em features menores, cada uma com sua própria spec.

## Links

- Plugin: https://github.com/obra/superpowers
- Instalação via marketplace: `/plugin install superpowers@claude-plugins-official`
- Tutorial de spec-driven: https://www.datacamp.com/tutorial/spec-driven-development-with-claude-code
