# Disciplina de contexto para agentes

Contexto é um **recurso finito com retornos decrescentes**. O objetivo é o menor conjunto de tokens de alto sinal que resolve o trabalho. A plataforma cuida da maquinaria pesada (compactação de histórico, limpeza de resultado de tool, memória); **seu trabalho é não gerar inchaço em primeiro lugar.**

Portável — se aplica a qualquer repositório. Todo agente aqui deve seguir isto.

## Princípios

- **Retorne conclusões, não material bruto.** Notas, não ensaios. Um resumo/diff-stat/decisão, não uma transcrição ou um despejo de arquivo. Se você leu 10 arquivos, reporte o que encontrou, não o conteúdo deles.
- **Leia de forma estreita.** Prefira `grep`/`Read` pontual (offset/limit) a ler arquivos inteiros. Leia a parte de que precisa, não o arquivo "para contexto".
- **Isole trabalho volumoso em subagentes.** Faça dispatch de leitura pesada ou implementação para um subagente e traga de volta só o seu **resumo**. O inchaço de uma tarefa não pode poluir o contexto do pai.
- **Externalize o estado.** Use `tasks.md`, `lessons.md`, ou notas curtas como memória duradoura em vez de carregar tudo na conversa.
- **Refazível supera armazenado.** Se você pode reler um arquivo ou refazer uma query depois, não guarde a saída completa dela, guarde o ponteiro (caminho, id) e refaça a busca quando precisar.
- **Direcione o formato da saída quando você faz dispatch.** Diga ao worker exatamente o formato mínimo que você precisa de volta (ex.: "retorne os arquivos alterados e um resumo de um parágrafo", não "mostre seu trabalho").
- **Continue um agente em vez de despachá-lo de novo.** Primeira passada num artefato → dispatch novo. Segunda e terceira passada no **mesmo** artefato → continue o agente vivo. Um novo dispatch relê tudo do zero e esqueceu o que já tinha sinalizado; uma continuação custa uma fração e ainda lembra dos próprios achados.
- **Uma memória declarada não é uma memória usada.** Um agente com `memory:` no seu frontmatter tem um caderno duradouro entre execuções. Diga a ele para ler esse caderno primeiro e acrescentar o que aprendeu, senão a configuração é decoração e o agente rederiva as mesmas convenções toda execução.

A mecânica de dispatch, paralelismo, background, teto de concorrência, vive em `.claude/docs/harness/dispatching.md`. Quem escreve o código vive em `.claude/rules/harness/delegation.md`.

## Checklist rápido

- [ ] Eu colei saída de arquivo/tool que eu poderia ter resumido ou apontado?
- [ ] Eu li um arquivo inteiro quando um `grep` + leitura pontual bastaria?
- [ ] Esse passo volumoso poderia ser um subagente que retorna só um resumo?
- [ ] Eu estou mantendo estado na conversa que pertence a `tasks.md`/`lessons.md`?

## Referência

Anthropic cookbook — context engineering for tools/agents (compaction, tool-result clearing, memory). Este documento distila a parte prática para um workflow spec-driven, baseado em subagentes.
