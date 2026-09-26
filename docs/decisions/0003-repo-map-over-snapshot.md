# 0003 - Repo map substitui o snapshot Repomix como contexto panorâmico

**Status:** Accepted
**Date:** 2026-09-23
**Decider:** Danilo Rodrigues

## Contexto

O harness instruía os agentes a tratar um snapshot Repomix em
`.claude/context/repomix-snapshot.md` como contexto panorâmico do codebase:
o `analyze-codebase` o gerava para qualquer projeto com 100 ou mais arquivos
de código, o `codebase-explorer` o lia para perguntas do tipo "quais módulos
existem" / "onde vive X" e o atualizava automaticamente quando ficava
obsoleto, e um hook de `SessionStart` avisava quando ele envelhecia. A
premissa era "empacotar o codebase inteiro num único arquivo que um agente
possa ler do início ao fim."

Medido contra os repositórios reais em que este harness é usado:

| Repo | Arquivos de código rastreados | Tamanho do snapshot | Tokens aprox. |
|---|---:|---:|---:|
| njord-back | 1.106 | 4,5 MB (`files_captured: 877`, subcontado) | ~1.127.000 |
| njord-front | 2.844 | 3,8 MB (`files_captured: 0`, o próprio contador estava quebrado) | ~950.000 |
| website | 217 | nenhum gerado | n/a |
| sales-funnel | 119 | nenhum gerado | n/a |

Um arquivo de 1,1M tokens não cabe na janela de contexto de nenhum modelo;
lê-lo inteiro nunca foi de fato possível, só assumido. Na prática era um alvo
de grep que custava 8 ou mais segundos para regenerar por completo (sem
caminho incremental), envelhecia silenciosamente entre regenerações e, no
njord-front, já estava reportando errado a própria contagem de arquivos, um
sinal de que ninguém estava checando. `website` e `sales-funnel` nunca
cruzaram o limiar de 100 arquivos, então o `analyze-codebase` nunca gerou um
snapshot para eles, e o `codebase-explorer` não tinha nada para usar como
fallback além de grep/glob improvisado, sem documentação como comportamento real.

## Opções consideradas

1. **Um repo map pequeno e determinístico.** Árvore de diretórios com
   contagem de arquivos por diretório, pontos de entrada, localização de
   testes e o bloco de comandos do `AGENTS.md`. Cresce com a quantidade de
   diretórios, não com o conteúdo dos arquivos.
   - Prós: cabe facilmente independentemente do tamanho do repositório;
     regenera em menos de um segundo; sem npx, sem rede, sem dependência de
     versão do Node; nada para cachear ou ficar obsoleto (barato o
     suficiente para regenerar em todo uso).
   - Contras: mais superficial do que ler o conteúdo real dos arquivos.
     Responde "onde vive X", não "como X funciona".
2. **Manter o snapshot, mas só como alvo de grep/leitura.** Parar de chamá-lo
   de "contexto", adicionar uma verificação rígida de orçamento de tamanho,
   documentá-lo como ferramenta manual/de colar (paste).
   - Prós: mudança mínima; alguns adotantes ainda podem querer uma
     exportação de arquivo único para uma ferramenta sem acesso ao sistema
     de arquivos.
   - Contras: como mecanismo de busca, não adiciona nada que `Grep`/`Glob`
     já não façam diretamente contra os arquivos ativos. Sem etapa de
     empacotamento, sempre atualizado, respeita `.gitignore` nativamente.
     Mantê-lo como mecanismo *padrão* significaria manter um arquivo gerado
     e esquecido de vários megabytes, sem leitor e sem nenhuma capacidade
     que o `Grep` não tenha.
3. **Descartar o snapshot completamente acima de um limiar.** Deixar
   `Grep`/`Glob` mais um mapa fazerem o trabalho, que é o que o
   `codebase-explorer` já efetivamente fazia quando um snapshot parava de caber.
   - Prós: nenhum mecanismo morto ficando ativo por padrão.
   - Contras: por si só, perde completamente o caso de uso "um arquivo para
     entregar a uma ferramenta externa sem acesso ao sistema de arquivos".

## Decisão

Escolhemos a **opção 1, combinada com rebaixar a opção 2 para totalmente
manual/opcional** (um híbrido das três, não a escolha pura de uma):

- **O repo map (`baseline/scripts/repo-map.sh` -> `.claude/context/repo-map.md`)
  se torna o artefato de contexto panorâmico.** O `codebase-explorer` o
  executa do zero como primeiro passo para perguntas de "o que existe / onde
  vive X", no lugar da antiga verificação de obsolescência do snapshot. Ele é
  barato o suficiente (ver Medido abaixo) que não há nada para cachear e nada
  para avisar sobre ficar obsoleto. Regenerá-lo é a própria estratégia de frescor.
- **O snapshot Repomix é rebaixado, não deletado.** O `analyze-codebase` não
  gera mais um automaticamente, o `codebase-explorer` não lê mais nem
  atualiza automaticamente nenhum. A skill `refresh-snapshot` ainda existe,
  reescrita para dizer claramente o que ela é agora: uma exportação manual e
  opcional, de arquivo único, para entregar a alguma outra ferramenta sem
  acesso ao sistema de arquivos, nunca contexto que um agente do Claude Code
  lê por conta própria. O `check-snapshot.sh` ganhou um orçamento rígido de
  tamanho (300.000 bytes, ~75 mil tokens pela própria estimativa do
  repositório de ~4 bytes/token) e um veredito `too-large` que dispara
  independente da obsolescência; o `check-snapshot-on-session.sh` agora só
  avisa em `too-large`, nunca por idade, já que nada mais lê o arquivo
  automaticamente e um aviso de obsolescência sobre um artefato que ninguém
  lê é ruído, não sinal.
- Não fomos com uma opção 3 pura (deletar o Repomix de vez) porque o caso "um
  arquivo único para uma ferramenta sem acesso ao sistema de arquivos" é real
  e barato de manter vivo, uma vez que ele não pode mais se passar por algo
  em que o próprio harness confia.

### Medido: tamanho do repo map nos mesmos repositórios

Gerado com `baseline/scripts/repo-map.sh`, sem flags:

| Repo | Arquivos rastreados | Tamanho do repo map | Tokens aprox. | vs. snapshot antigo |
|---|---:|---:|---:|---:|
| njord-back | 1.106 | 6,1 KB | ~1.500 | ~740x menor |
| njord-front | 2.844 | 3,8 KB | ~950 | ~1.000x menor |
| website | 217 | 2,6 KB | ~650 | n/a, nenhum snapshot existia |
| sales-funnel | 119 | 2,1 KB | ~525 | n/a, nenhum snapshot existia |

Todos os quatro ficam bem abaixo do orçamento de 75 mil tokens que o snapshot
antigo nunca cumpriu nos dois repositórios grandes o bastante para ter um sequer.

## Consequências

### Positivas

- O primeiro passo do `codebase-explorer` agora é algo que de fato completa
  e de fato cabe, em todo repositório medido, não só nos com menos de 100
  arquivos.
- Sem cache, sem matemática de obsolescência, sem divergência para o artefato
  que importa no dia a dia: o repo map é regenerado, não confiado de uma
  execução anterior.
- A premissa falsa ("este arquivo é contexto que você pode ler") desapareceu
  do `codebase-explorer`, do `analyze-codebase`, do `refresh-snapshot` e do
  hook de `SessionStart`, e nenhum deles produz mais silenciosamente algo inutilizável.
- `website` e `sales-funnel`, que nunca tiveram snapshot algum sob o antigo
  limiar de 100 arquivos, recebem exatamente o mesmo artefato panorâmico que
  todo outro repositório recebe. Não há mais limiar para ficar abaixo dele.
- O caso de uso da exportação manual (entregar um arquivo a uma ferramenta
  sem acesso ao sistema de arquivos) ainda funciona, agora honestamente
  rotulado e verificado por orçamento em vez de confiado silenciosamente.

### Negativas

- O repo map é mais superficial do que a leitura de um snapshot real: ele não
  consegue responder "como o guard de autenticação de fato valida um token",
  só "onde vive o código de autenticação". O `codebase-explorer` ainda
  precisa de `Grep`/`Glob`/`Read` para qualquer coisa além do "onde".
- A extração do bloco de comandos do `AGENTS.md` no `repo-map.sh` é uma
  heurística (primeiro bloco cercado sob um cabeçalho que case com
  Build/Test/Lint/Command/Scripts). Um repositório cujo `AGENTS.md` estrutura
  essa seção de forma diferente recebe um resultado degradado, mas não
  quebrado ("leia o AGENTS.md diretamente").
- Um adotante que ainda quer uma exportação Repomix sempre atualizada para
  uma ferramenta externa agora precisa executar `refresh-snapshot`
  manualmente. Ela não é mais produzida automaticamente pelo `analyze-codebase`.

### Riscos aceitos

- O orçamento de tamanho de 300.000 bytes / ~75 mil tokens é uma decisão de
  julgamento, não derivada da janela de contexto real de nenhum modelo. Se na
  prática se mostrar muito rígido ou muito solto, é uma constante de uma
  linha para revisitar, não um redesign.
- As heurísticas de ponto de entrada e localização de testes em
  `repo-map.sh` foram ajustadas contra este repositório e
  njord-back/njord-front/website/sales-funnel. Um repositório com um layout
  fora do comum (um monorepo com pacotes profundamente aninhados, por
  exemplo) pode receber um mapa menos útil; ele degrada para "grep/glob
  diretamente", o mesmo fallback que existia antes desta mudança.

## Revisitar quando

- A estrutura real do `AGENTS.md` de um repositório quebrar a heurística do
  bloco de comandos com frequência suficiente para valer uma segunda
  estratégia de extração.
- Alguém realmente precisar do caminho de exportação Repomix manual e achar o
  orçamento de 300.000 bytes errado para o próprio caso, em qualquer direção.
- O próprio repo map precisar de uma segunda camada, mais profunda (resumos de
  README por módulo, por exemplo) porque "onde vive X" deixar de ser
  suficiente. Nesse ponto esta ADR deveria ser supersedida, não editada.
