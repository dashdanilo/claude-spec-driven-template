---
paths: "specs/**"
---

# Specs — afirmações precisam ser verificadas, não copiadas

## A regra

- **Toda afirmação sobre o estado atual do sistema é verificada contra o código, o schema ou o git, no momento em que é escrita.** Não copiada de um documento existente, não importa quão bem escrito.
- **Uma spec escrita ou editada à mão ainda passa pelo `spec-reviewer`.** O `write-spec` o invoca automaticamente; uma spec que você digitou você mesmo não recebe isso de graça, e é justamente a que ninguém auditou.
- **Um "fix pendente" referenciado é checado antes de se tornar uma tarefa.** Branches e PRs fechados ficam obsoletos nas duas direções.

## Prosa é um registro, não uma fonte

A narrativa de uma spec existente diz o que era verdade **quando alguém a escreveu**. Um cabeçalho datado (`Onde paramos (2026-07-16)`) é um selo de alerta, não uma autoridade. Quanto mais antiga e mais confiante a prosa, mais ela merece uma checagem — um parágrafo obsoleto bem escrito é mais perigoso que um tosco, porque ele lê como algo resolvido.

Isso corta nos dois sentidos, e o segundo é o que as pessoas deixam passar:

| direção | o que você encontra | custo de não checar |
|---|---|---|
| trabalho dito como feito, na real pendente | os checkboxes mentiram de forma otimista | você entrega uma lacuna |
| **trabalho dito como pendente, na real feito** | a dívida foi paga e ninguém atualizou o documento | **você planeja e executa um trabalho que já existe** |

## A checagem mais barata para um "fix pendente"

Quando um documento diz que um fix está esperando numa branch ou num PR fechado:

```bash
git cherry-pick <sha>     # resultado vazio = o conteúdo já está na sua base
```

**Um cherry-pick que volta vazio é o sinal.** Ele significa que a mudança foi reaplicada sob um commit ou número de PR diferente, então buscar pelo PR original o encontra fechado e você conclui, erroneamente, que o trabalho está pendente. Cheque o arquivo, não o status do PR.

Mesma ideia sem aplicar nada: `git log --oneline <base> -- <the file>` e leia o que de fato foi consolidado.

## Desvios vão em `deviations.md`, não no artefato que contaminaram

Execuções longas ou autônomas se desviam do plano. Isso não é uma falha, absorver isso silenciosamente é. Quando a execução se afasta do que foi acordado, acrescente em `specs/<slug>/deviations.md`:

```markdown
## <date> — <one-line what changed>
- **Agreed:** <what the plan/tasks said>
- **Did:** <what actually happened>
- **Why:** <the reason, including the blocker or assumption that forced it>
- **Consequence:** <what is now true that the plan does not describe>
- **Status:** accepted | to revert | needs decision | finding
```

Quatro coisas pertencem aqui: uma **suposição** (`assumption`) tomada sem confirmação, um **bloqueio** (`blocker`) contornado, uma **mudança de escopo** (`scope change`) decidida no meio da execução, e trabalho executado **fora do pipeline** (fases rodadas direto a partir do `plan.md`, edições feitas na thread principal — nenhuma das duas nunca ganha um checkbox marcado por ninguém).

**`finding`** é um quinto tipo, diferente por natureza: um defeito de produção que um teste revelou e que está **fora do escopo** desta spec, a tarefa não pediu por ele, o fix não pertence a este diff. Registre aqui mesmo assim, em vez de perdê-lo ou de fazer scope-creep na tarefa para corrigi-lo. Um `finding` **não bloqueia** a execução.

Não os escreva em `tasks.md`. Checkboxes são legíveis por máquina e prosa não é; uma narrativa encaixada entre caixas é lida por humanos e ignorada pelo plano da próxima wave, o que é o peor dos dois mundos.

`needs decision` é o único status que bloqueia. É o que um `/handover` precisa expor e um reviewer precisa resolver. Um `finding` aberto não bloqueia, mas também não fica invisível, ele pertence ao corpo do PR (`/orchestrate` Step 4) e às decisões abertas do `/handover`, o mesmo que `needs decision`.

## Por que isso é uma regra

Medido no próprio trabalho deste template: uma spec de follow-ups foi escrita a partir de um cabeçalho de três semanas atrás que dizia que dois testes estavam falhando. Eles já tinham sido corrigidos e mergeados sob um número de PR diferente. A spec, sua lista de tarefas e uma descrição de PR publicada carregavam todas a premissa errada — e o bloqueio estava classificado como prioridade 1, então seria a próxima coisa a ser construída.

A defesa já existia (`write-spec` entrega a spec ao `spec-reviewer` para verificar as afirmações contra a base de código). Foi pulada porque a spec foi escrita à mão. Um guard que só dispara no caminho feliz não é um guard.
