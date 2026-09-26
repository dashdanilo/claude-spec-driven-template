# 0002 - Harness visibility: a symlink-based harness is invisible to a symlink-blind reader

**Status:** Accepted
**Date:** 2026-09-23
**Decider:** Danilo Rodrigues

## Contexto

Este diretório continha apenas [`0001-example.md`](./0001-example.md) até agora. As
decisões reais sobre como este harness é distribuído e consumido foram tomadas
e registradas no repositório privado `njord-app/marketplace`, porque foi lá
que as consequências multi-repo apareceram primeiro:

- **ADR 0001** (marketplace) escolheu symlinks em vez de cópias, um plugin, ou um
  submódulo git, de forma que uma mudança no harness é escrita uma vez e fica ativa
  em todo lugar onde está linkada, sem nada em namespace e sem nada excluído.
- **ADR 0003** (marketplace) tornou esse symlinking por projeto e opcional,
  com caminhos absolutos e **nada commitado**: os links vivem em
  `.git/info/exclude`, nunca em `git ls-files`. Isso é explicitamente o que torna
  seguro linkar um repositório que outras pessoas compartilham: "um colega de time
  que clona o repo não vê nenhum symlink pendurado, e o CI não vê nada."
- **ADR 0004** (marketplace) mudou a granularidade do link, de um link por
  pasta inteira `skills/`/`agents/` para um link por item
  (`.claude/skills/<name> -> <checkout>/baseline/skills/<name>`), de forma que
  as próprias skills e agentes de um repo adotante continuam funcionando junto com o harness.

Essa divisão é errada para um template público: quem lê este repositório não
consegue ver o raciocínio por trás do próprio mecanismo de entrega do harness, a menos
que também tenha acesso a um repositório privado da organização. Esta ADR é a primeira
escrita aqui sobre a visibilidade do próprio harness, e trata as três ADRs do
marketplace acima como o registro anterior, em vez de reabrir a discussão.

O gatilho imediato: executar o [`harness-score`](https://github.com/paladini/harness-score)
(uma CLI determinística, sem rede e sem LLM, que pontua o harness de agentes de um
repositório de 0 a 108 em seis dimensões e mapeia isso para um nível de maturidade
L0-L4) contra `njord-back`, `njord-front`, `website`, `sales-funnel`, e este
próprio template, em 2026-09-23, produziu duas distorções:

1. **Skills & Commands pontua 0/17 em quatro dos cinco repositórios**, incluindo
   o symlink deste próprio template, commitado, na raiz, `.claude/skills -> ../baseline/skills`,
   apesar do harness estar totalmente presente e funcionando numa sessão viva do
   Claude Code em todos eles.
2. **`njord-back`, em vez disso, pontuou um L4 enganosamente alto, 99/108.** Um
   diretório `.claude/worktrees/<name>/` obsoleto, deixado de uma execução
   anterior do harness, ainda guarda uma cópia antiga, totalmente vendorizada
   (arquivos reais, não symlinks) de 48 skills e 20 agentes, sem relação com o
   estado real e atual do harness symlinkado do repositório.

### O que o mecanismo realmente é (lido do próprio código da ferramenta, não deduzido)

O varredor de arquivos do `harness-score` (`packages/cli/src/scan.ts`) segue
symlinks, mas só até certo ponto, e esse ponto importa:

- Um diretório symlinkado cujo realpath resolve **fora da raiz do escaneamento** é
  excluído da lista de arquivos, e o código marca **todo o escaneamento** como
  `incomplete` (`outside-root-symlink`), em vez de simplesmente pontuá-lo como se
  o harness não estivesse lá. O próprio README da ferramenta diz que a pontuação de
  um escaneamento incompleto não deve ser "publish[ed] ... as authoritative" ("publicada
  ... como autoritativa"). Isso é exatamente a convenção das ADRs 0003/0004:
  `.claude/skills/<name>` e `.claude/agents/<name>.md` são symlinks absolutos para
  um checkout que vive em outro lugar no disco, deliberadamente nunca commitado.
- Mais surpreendente: um diretório symlinkado **na própria raiz** também não ajuda.
  O próprio `.claude/skills -> ../baseline/skills` deste template está rastreado pelo git
  (modo `120000`), é relativo, e resolve dentro do repositório. O `harness-score`
  ainda assim pontua 0/17, porque o varredor deduplica pelo realpath canônico e sempre
  mantém o primeiro diretório **físico** encontrado, em vez de qualquer alias
  symlink para o mesmo destino (o próprio comentário do código: "a lexically
  earlier symlink cannot hide the canonical repository path for the same
  target", ou seja, "um symlink lexicamente anterior não pode esconder o caminho
  canônico do repositório para o mesmo destino"). `baseline/skills/` é varrido e
  reivindicado como o caminho canônico antes que `.claude/skills` seja expandido,
  então todo arquivo dentro dele é atribuído somente a `baseline/skills/...`, nunca a
  `.claude/skills/...`. As verificações individuais (`SKL-01`..`04`, `AGT-01`..`02`,
  casadas em `packages/cli/src/harness/registry.ts` contra padrões como
  `/(^|\/)\.claude\/skills\/[^/]+\/SKILL\.md$/`) exigem esse segmento literal de
  caminho `.claude/skills/`, `.cursor/skills/`, ou `.agents/skills/`;
  `baseline/skills/` nunca casa com nenhum deles, symlink ou não.
- Verificamos se havia uma válvula de escape antes de concluir que não havia:
  `--help`, a seção "Team customization" do README, e o parser de configuração
  (`packages/cli/src/config.ts`). O `.harness-score.json` suporta `extends`
  (presets nomeados), `rules` (severidade por verificação `off`/`error`, com três
  verificações de vazamento de credenciais que nunca podem ser desligadas), e
  `extraRoots`/`scopes` (adiciona um escaneamento totalmente separado e com raiz
  independente, que alimenta só o gate `effective`, não o gate `maturity` padrão,
  pensado para o escopo de usuário/sistema `~/.claude`). Nenhuma dessas opções
  remapeia ou cria alias de caminho para fins de casamento das verificações, e
  nenhuma muda os dois comportamentos acima. Não existe flag `--follow-symlinks`.
  É assim que o scanner foi construído, não é um bug para reportar nem uma flag
  que deixamos passar.
- Os padrões de caminho do registry também são **sem âncora**
  (`(^|\/)\.claude\/skills\/...` casa esse segmento em qualquer lugar da árvore),
  que é a outra metade da história do `njord-back`: seu diretório obsoleto
  `.claude/worktrees/<name>/.claude/skills/...` guardava arquivos reais (uma cópia
  antiga, totalmente vendorizada, não um symlink), então ele contou por completo,
  independentemente de a configuração atual do harness do repositório de nível
  superior estar visível ou não.

Efeito líquido: o harness é invisível para o `harness-score`, para o CI, e para um
clone recém-feito que não executou `install-harness.sh` localmente. Não por causa de
um bug no scanner e não por nada específico deste template, mas porque um harness
entregue por symlink e um varredor de arquivos que só olha realpath canônico e raiz
interna são estruturalmente incompatíveis. A própria pontuação do `harness-score`
para este repositório, portanto, subestima o harness; ela nunca pode sobrestimá-lo.

## Opções consideradas

1. **Não fazer nada, ignorar a pontuação.**
   - Prós: nenhum trabalho.
   - Contras: um 99/108 errado no `njord-back` e um 0/17 errado em skills
     em todo o resto são tratados como fato por qualquer um que não conheça o
     mecanismo acima, incluindo o novo job de CI deste próprio template.
2. **Aceitar e documentar.** Declarar claramente, aqui e em um guia, que a
   pontuação é um piso e nomear as duas distorções com a evidência concreta
   acima, para que ninguém precise deduzir isso de novo e ninguém confie em um
   99 ou um 0 pelo valor de face. Apontar para `install-harness.sh --status`, um
   comando já existente, já não commitado e sempre atual, como a forma real de um
   humano checar o que está linkado, em vez de adicionar um novo artefato.
3. **`install-harness.sh` escreve um marcador pequeno e commitado** (por exemplo
   `.claude/HARNESS.md`) listando as skills/agentes linkadas e o caminho do
   checkout, para que um clone recém-feito, o CI, ou um humano sem o harness
   linkado possa ao menos ver que um harness existe.

### Por que a opção 3 não se paga

Antes de escolher, pesamos exatamente o que commitar um marcador compraria:

- **Não move a pontuação.** As verificações de skills/agentes do `harness-score`
  exigem um `SKILL.md` literal (ou arquivo de frontmatter de agente) num caminho
  reconhecido; um arquivo de marcador em prosa não casa com nenhum `pathRegex`. A
  dimensão continua 0/17 mesmo assim. O design do scanner (preferir o realpath
  canônico, excluir symlinks fora da raiz) não consegue ver conteúdo delegado por
  construção, e um marcador é conteúdo delegado descrito em texto, não arquivos no
  caminho reconhecido.
- **Reintroduz exatamente o custo que a ADR 0003 gastou uma ADR inteira para remover.**
  A decisão da ADR 0003 se apoia em "nada é commitado ... seguro linkar um
  repositório que outras pessoas compartilham." Um marcador commitado num repositório
  adotante registraria o caminho absoluto de checkout específico da máquina de um
  desenvolvedor, diferiria entre cada colega que roda o instalador de um lugar
  diferente, e transformaria "um comando, sem diff" em "um comando, mais um commit,
  mais um conflito de merge na próxima vez que um colega rodar a partir do próprio
  caminho." A própria seção "Negative" da ADR 0003 já aceita que um colega sem o
  harness linkado "não o tem, e o CI nunca tem"; um marcador não muda esse fato, ele
  só torna o caminho local de um desenvolvedor visível no histórico do git para
  todo o resto, que é exatamente o risco que a 0003 foi escrita para evitar.
- **O único lugar onde um marcador poderia ajudar, a própria configuração de dogfood
  deste template, já tem um link commitado** (modo `120000`, relativo, na raiz),
  tornando um marcador redundante com `git ls-tree` e com `check-index.sh`, que já
  verifica os nomes linkados contra `baseline/` e detectaria uma divergência com a
  qual um marcador escrito à mão poderia silenciosamente perder sincronia.

## Decisão

**Opção 2: aceitar e documentar.**

- Esta ADR é o registro durável do mecanismo, para qualquer leitor deste
  repositório público.
- [`docs/guides/harness-score.md`](../guides/harness-score.md) é o guia
  operacional: como executar o scanner por repositório, como ler as seis
  dimensões, e as duas distorções acima com o exemplo exato do `njord-back`,
  para que ninguém confie num 99 de novo.
- Um job de CI do `harness-score` é adicionado ao próprio pipeline deste
  repositório, com gate em `--min-level 2`, o nível que o próprio harness deste
  repositório realmente mantém hoje num clone limpo, para que o job passe agora
  e falhe só numa regressão real, nunca na subcontagem preexistente de
  skills/agentes.
- Nós **não** mudamos o `install-harness.sh` nem adicionamos nenhum novo
  artefato commitado. O já existente, não commitado, `install-harness.sh --status`
  continua sendo a forma correta de um humano ver o que está de fato linkado num
  determinado checkout, e ele está sempre atual porque lê o sistema de arquivos
  em vez de um snapshot que pode divergir.

## Consequências

### Positivas

- Nenhum leitor deste repositório, humano ou CI, precisa redescobrir por conta
  própria por que o `harness-score` diverge da realidade; a ADR e o guia dizem
  isso claramente, com evidência no nível de arquivo e linha.
- O CI agora usa como gate um número real e determinístico para este
  repositório, em vez de ignorar o `harness-score` totalmente ou aceitar
  silenciosamente uma pontuação baixa sem explicação.
- Nenhum artefato novo commitado, nenhuma nova superfície de divergência, nenhum
  risco de reintroduzir o custo do "nada é commitado" da ADR 0003 em nenhum
  repositório adotante. Esta decisão não toca em nada do mecanismo de entrega em si.
- Registro público: as próprias PRs futuras dos repositórios njord (fora do
  escopo desta mudança) podem apontar para esta ADR em vez de refazer a mesma
  investigação.

### Negativas

- A subcontagem de skills/agentes é permanente enquanto o `harness-score`
  canonicalizar por realpath e este harness for entregue por symlink; nada neste
  repositório pode corrigir isso localmente. Toda leitura futura da pontuação
  precisa da mesma ressalva, para sempre, até a ferramenta upstream mudar ou este
  harness deixar de ser entregue por symlink.
- `--min-level 2` só prova que este repositório não regrediu para abaixo do que
  ele mantém hoje; não prova que a dimensão de skills/agentes está saudável,
  porque a ferramenta não consegue vê-la de qualquer forma. Uma regressão real em
  `baseline/skills/` (um `SKILL.md` quebrado, uma descrição faltando) não seria
  pega por este gate.
- Um futuro contribuidor sem familiaridade com esta ADR ainda poderia ver "L2, 62/108"
  no CI e assumir que isso significa algo que não significa; o guia reduz esse
  risco mas não o elimina.

### Riscos aceitos

- Se o `harness-score` algum dia mudar seu comportamento de canonicalização de
  symlink (ver "Revisitar quando"), a pontuação documentada deste repositório
  saltaria, e a explicação da ADR precisaria de uma nota supersedente, em vez de
  uma edição silenciosa.
- A versão fixada do `harness-score` no CI (ver o guia) pode ficar obsoleta;
  atualizá-la é um passo deliberado e revisado, não automático, precisamente
  porque a própria política de semver da ferramenta permite que o modelo de
  maturidade em si mude numa versão minor.

## Revisitar quando

- O `harness-score` ganhar uma forma documentada de criar alias ou remapear um
  caminho para fins de casamento das verificações (uma chave de configuração
  `overlay`/`alias`, ou um modo `--follow-symlinks` que mantenha todo caminho
  relativo alcançável em vez de só um canônico). Nesse ponto, a opção 3 volta a
  valer a pena recalcular o custo, já que a objeção acima é sobre retorno, não
  sobre princípio.
- O próprio mecanismo de entrega do harness deixar de usar symlinks (rastreado
  nas próprias seções "Revisit when" das ADRs do marketplace, por exemplo um
  campo `rules` chegando no manifesto de plugin do Claude Code). Um harness
  baseado em cópia ou plugin não teria esse ponto cego e esta ADR precisaria de
  uma nota supersedente.
- O worktree obsoleto do `njord-back` (ou de qualquer repositório) for limpo e sua
  pontuação cair para refletir a realidade. Vale um adendo de uma linha aqui, em
  vez de deixar silenciosamente o próximo leitor assumir que o 99 algum dia foi real.
