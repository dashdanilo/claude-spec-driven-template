---
paths: "**"
---

# Delegation — quem de fato escreve o código

A thread principal **coordena**; especialistas **implementam**. Esta regra carrega sempre, porque é a disciplina que se degrada primeiro.

## A divisão

| Trabalho | Onde | Por quê |
|---|---|---|
| Exploração — grep, glob, leituras pontuais, "onde vive X?" | inline está ok | barato, e você quer a resposta na sua frente |
| **Implementação — Edit/Write em arquivos de código-fonte** | **dispatch para um especialista** | o especialista carrega as convenções da stack e começa com um contexto limpo |
| Verificação — gate, testes, review | dispatch (`tester`, `code-reviewer`, `reviewer`) | um contexto independente pega o que o do autor não pega |

## Inegociável

- **Nunca escreva código de feature a partir da thread principal.** Se você está prestes a fazer Edit ou Write num arquivo de código-fonte para a tarefa em questão, dispatch em vez disso.
- **Não existir especialista para esta stack é uma lacuna do plugin de stack, não permissão para fazer na mão.** Faça dispatch do `implementer` do baseline — ele é o fallback portável e lê o repositório antes de escrever — e sinalize o especialista ausente. **Não** recorra ao agente embutido `general-purpose`: ele não sabe nada sobre o repositório e o redescobre a cada execução, medido numa mediana de 122 chamadas de tool, o agente mais caro do estado atual.
- A thread principal é dona de exatamente cinco coisas: o plano, os checkboxes do `tasks.md`, a decisão do gate, a conversa com o humano e, antes de qualquer uma das anteriores começar, onde o trabalho acontece (local, o worktree próprio da ferramenta de agente, ou `spec-worktree`; veja "Where the work happens" em `.claude/rules/harness/git-workflow.md`).

## Exceções restritas

- Uma correção de uma linha que o gate verifica imediatamente — mais barato inline do que num round-trip.
- Os próprios documentos do orquestrador: `tasks.md`, `spec.md`, `plan.md`, `lessons.md`, `deviations.md`, ADRs.
- O humano pediu explicitamente para você fazer a edição você mesmo.

Qualquer outra coisa é um dispatch.

## Por que isso é uma regra e não um conselho

Fazer você mesmo sempre parece mais rápido no momento, e nunca é: a thread principal acumula cada arquivo que toca, então já na terceira tarefa o contexto dela está pior que o de um especialista novo — e é o contexto em que o humano está sentado.

Medido num projeto real rodando este template: **71% das chamadas de `Edit` aconteceram na thread principal**, enquanto `Grep`/`Glob` foram **100% delegadas**. A exploração estava sendo delegada e a implementação não — exatamente ao contrário. A thread principal terminou carregando 71% do gasto total de tokens, num sistema cujo próprio documento de contexto diz para mantê-la magra.

Veja `.claude/docs/harness/dispatching.md` para *como* fazer dispatch (paralelismo, background, re-review) e `.claude/docs/harness/context-engineering.md` para o que enviar e receber de volta.
