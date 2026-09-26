# Despachando subagentes

*O quê* delegar está em `.claude/rules/harness/delegation.md`. *Que contexto* passar está em `.claude/docs/harness/context-engineering.md`. Este documento é o **como**, paralelismo, background, re-review, memória.

Só para IA. Portável: sem suposições de stack.

## Decida se vale a pena fazer dispatch

Antes da forma, a pergunta anterior. Fazer dispatch não é gratuito e nem sempre é melhor.

| se o trabalho é | faça isto | por quê |
|---|---|---|
| uma varredura na base de código, uma busca, pesquisa | **sempre faça dispatch** | o subagente lê amplamente e retorna só o destilado; a amplitude nunca entra na sua janela |
| muitas tarefas, ou uma execução acima de ~30 minutos | **dispatch, agrupado em alguns clusters coesos** | sua janela se enche antes de começarem as correções, que é onde o trabalho de fato está |
| pequeno e autocontido | **inline** | uma ida e volta custa mais do que a própria edição, e o especialista relê o que você já tem |
| genuinamente paralelizável, arquivos disjuntos | **dispatch** | este é o único caso em que velocidade é o motivo |

## O quão fino cortar, e por que não é "o mais fino possível"

Medido num épico de 18 tarefas, uma execução por arquitetura, pelo [Tech Leads Club](https://agent-skills.techleads.club/tlc-spec-driven/):

| como você corta | tokens | tempo | qualidade | thread principal usada |
|---|---|---|---|---|
| inline, sem dispatch | 9M | 19m | 0.93 | **74%** |
| **~3 clusters coesos** | 10.5M | 18m | **0.95** | **26%** |
| um por fase (7) | 15M | 35m | 0.90 | 24% |
| **um por tarefa (18)** | **25M** | **43m** | **0.81** | 32% |

Três leituras, e só a primeira é intuitiva.

**Granularidade destrói qualidade.** Todo dispatch começa do zero, relê os arquivos e perde o todo. Um agente por tarefa é a pior linha em todos os eixos, inclusive contra não fazer dispatch nenhum.

**Mais workers pode deixar a thread principal mais gorda.** Dezoito workers usaram *mais* dela do que sete, porque o resumo de cada worker chega lá. Fan-out tem um custo justamente no lado que você estava tentando proteger, e é por isso que um cluster é instruído a reportar uma vez, não uma vez por tarefa.

**O ganho é orçamento de contexto, não velocidade.** Dezoito minutos contra dezenove não é um ganho de velocidade. O que foi comprado foi terminar em 26% em vez de 74%, então as rodadas de correção saem baratas em vez de degradar. Em 18 tarefas o custo em tokens é neutro; além disso, a linha inline infla e o clustering começa a vencer de forma clara.

O desacordo do setor se dissolve aqui. A Anthropic reporta subagentes custando mais mas respondendo melhor em trabalho de longa duração; a Cognition reporta eles fragmentando contexto e sendo perigosos. As duas coisas são verdade em granularidades diferentes, e granularidade é a variável.

**Trate a forma como estabelecida e o número como uma hipótese.** É um épico, uma base de código, uma execução por célula, e os próprios autores chamam 0,93 vs 0,95 de estatisticamente iguais. Dimensione por **tarefas por especialista** (5-7), não por um número fixo de clusters: três clusters de 20 tarefas explodiriam cada janela. Veja `harness-baseline.md`.

## Escolha a forma antes da mecânica

Seis formas cobrem quase todo dispatch que você vai planejar. Escolha a forma a partir do *trabalho*, depois aplique a mecânica abaixo. Escolher a forma errada custa mais do que qualquer mecânica consegue corrigir: um fan-out sobre tarefas dependentes desperdiça toda execução paralela, e um pipeline sobre tarefas independentes desperdiça tempo de relógio.

### 1. Pipeline

```
[A] → [B] → [C] → [D]
```

Cada estágio consome a saída do estágio anterior.

- **Se encaixa quando** cada passo depende fortemente do artefato anterior.
- **Cuidado:** um estágio lento atrasa tudo depois dele. Desenhe os estágios para serem o mais independentes possível.
- **Com subagentes:** natural. Um dispatch por estágio; você passa cada resultado para o próximo prompt. O custo é que toda transição passa por você.

### 2. Fan-out / Fan-in

```
        ┌→ [A] ─┐
[split] ┼→ [B] ─┼→ [merge]
        └→ [C] ─┘
```

Mesma entrada, várias lentes independentes, depois um merge.

- **Se encaixa quando** o mesmo artefato precisa de lentes diferentes (correção, segurança, testes, performance).
- **Cuidado:** o **merge** decide a qualidade. Um merge malfeito descarta tudo que as execuções paralelas encontraram.
- **Com subagentes:** faça dispatch de todos **numa mensagem só**, esta é a forma em que essa regra mais compensa. Faça o merge você mesmo, ou dê a ele seu próprio dispatch quando for pesado.
- **O sintetizador trata os três resultados explicitamente**, não só o caminho feliz: **tudo retornou** mergeia normalmente; **parcial** (algumas branches voltaram, uma morreu ou deu timeout) ainda mergeia o que chegou, e nomeia qual branch está faltando em vez de silenciosamente apresentar um merge de cobertura completa; **zero retornou** não é um merge sem nada dentro, é uma falha reportada, igual a uma falha de dispatch em qualquer outro ponto deste documento. Um merge que não consegue dizer ao leitor qual dos três aconteceu é pior do que nenhum merge.

### 3. Pool de especialistas

```
[router] → { [A] | [B] | [C] }
```

Um router escolhe o único especialista de que a entrada precisa.

- **Se encaixa quando** o tipo de entrada decide o tratamento.
- **Cuidado:** a precisão de classificação do router *é* o padrão. Tudo abaixo herda o erro dele.
- **Com subagentes:** ideal. Você chama só o especialista de que precisa e nada fica parado.

### 4. Producer-Reviewer

```
[produce] → [review] → (findings) → [produce again]
```

- **Se encaixa quando** qualidade importa e existe um critério objetivo para checar contra.
- **Cuidado:** **limite as tentativas a 2-3.** Sem um limite isso entra em loop infinito, e cada volta custa uma passada completa.
- **Escale num platô, não só no limite.** Se a pontuação ou a contagem de findings abertos não está melhorando rodada a rodada (a rodada 2 deixa a mesma quantidade aberta que a rodada 1, ou novos findings aparecem tão rápido quanto os antigos fecham), isso é sinal de que a correção está tratando um sintoma e não a causa. Pare nesse ponto mesmo que ainda restem rodadas dentro do limite de 2-3, e escale para um humano com o ledger aberto em vez de gastar a rodada restante na mesma abordagem.
- **Com subagentes:** dois dispatches por rodada, alimentando os findings do reviewer no próximo prompt do producer. O mesmo loop que o gate já roda. Prefira continuar o reviewer vivo na rodada 2 (veja abaixo) em vez de fazer dispatch de um novo.

### 5. Supervisor

```
          ┌→ [worker A]
[super]  ─┼→ [worker B]     ← assigns as it watches progress
          └→ [worker C]
```

- **Se encaixa quando** a carga de trabalho é variável ou só é conhecível em tempo de execução, uma migração em que você aprende a forma real conforme avança.
- **Difere do fan-out:** o fan-out fixa a divisão de antemão; o supervisor ajusta no meio da execução.
- **Cuidado:** o supervisor se torna o bottleneck se a unidade delegada for pequena demais. Delegue em blocos grandes o suficiente para valer a ida e volta.
- **Com subagentes:** a thread principal é o supervisor. Mantenha o estado das atribuições na lista de tarefas compartilhada, não no seu contexto, é isso que impede o supervisor de inchar.

### 6. Delegação hierárquica

```
[coordinator] → [lead A] → [worker A1] [worker A2]
              → [lead B] → [worker B1]
```

- **Se encaixa quando** o problema se decompõe hierarquicamente por conta própria.
- **Cuidado:** **acima de dois níveis, latência e perda de contexto dominam.** Mantenha em dois.
- **Com subagentes:** possível (um agente despachado pode despachar o seu próprio), mas prefira achatar para um nível mais um merge. Profundidade compra menos do que custa.

### Composições são a norma

| Composição | Forma | Exemplo |
|---|---|---|
| Fan-out + Producer-Reviewer | produção paralela, cada saída revisada | vários módulos construídos em paralelo, cada um revisado por conta própria |
| Pipeline + Fan-out | estágios sequenciais com um estágio paralelo dentro | analisar (serial) → implementar (paralelo) → teste de integração (serial) |
| Supervisor + Pool de especialistas | supervisor classifica, depois chama o especialista certo | triagem de um backlog, roteando cada item para sua camada |

### Um modo que este harness não tem

Existe um segundo modo de execução, **agent teams**, em que os membros são instâncias independentes que trocam mensagens diretamente entre si e se autocoordenam através de uma lista de tarefas compartilhada. Ele muda a resposta para fan-out e producer-reviewer, porque a descoberta de um membro pode redirecionar outro no meio da execução em vez de só depois que ambos terminarem.

Ele **não está disponível aqui** (sem tool de criação de team), então toda linha acima foi escrita para subagentes. Se algum dia estiver, a regra prática é uma pergunta: *a descoberta de um worker muda o que outro deveria estar fazendo?* Sim → team. Não → subagentes, e a comunicação seria puro overhead.

> Catálogo de padrões adaptado de [revfactory/harness](https://github.com/revfactory/harness) (Apache-2.0), reescrito para execução com subagentes.

## Paralelo significa uma mensagem, vários dispatches

Trabalho independente roda **concorrentemente só quando os dispatches saem numa única mensagem**. Várias chamadas de agente numa mensagem rodam ao mesmo tempo; uma chamada por mensagem roda uma depois da outra, não importa quão independentes as tarefas sejam.

```
Wave with 3 independent tasks
  ✅ one message  → Agent(task A) + Agent(task B) + Agent(task C)   ← concurrent
  ❌ three messages, one Agent each                                  ← sequential, 3× the wall-clock
```

Essa é a mecânica mais esquecida de todas. Num projeto real, **54 de 54 dispatches saíram um por mensagem**, o plano de wave existia no papel e nunca fez fan-out de fato. A sobreposição que aconteceu veio de dispatches em background que acidentalmente sobreviveram um ao outro, chegando a 3 no pico.

Antes de despachar uma wave, pergunte: *essas tarefas tocam arquivos disjuntos?* Se sim, elas pertencem a uma mensagem. Se não, pertencem a waves diferentes (veja document ownership em `.claude/docs/harness/principles.md`).

**Agentes de verificação não estão isentos de disjunção.** `tester`, `code-reviewer` e `reviewer` escrevem só o próprio entregável, um arquivo de teste, um relatório, uma descrição de PR, nunca um arquivo rastreado que pertence a outra pessoa, e nunca um arquivo rastreado para um mutation check (mute uma cópia em scratchpad/tmp com o import redirecionado, em vez disso). Medido: um `tester` e um `code-reviewer` despachados juntos, na mesma árvore, o reviewer mutou um arquivo helper no lugar para checar se uma asserção o matava, o tester rodou a suíte naquela mesma janela, bateu num gate vermelho contra um arquivo de produção modificado mais um `.bak` perdido, e corretamente se recusou a revertar algo que não era dele. A regra de disjunção de arquivos acima foi escrita para quem autora o entregável; ela não previu que verificação também escreve.

## Background é para trabalho longo que você coleta neste turno

- **Use background** para uma execução longa e autocontida que você vai coletar antes do turno terminar.
- **Nunca coloque um gate em background.** O trabalho todo de um gate é bloquear; um gate que você não espera não bloqueia nada.
- **Colete o que você lança, no turno em que lançou.** Num projeto real, dois dispatches em background só foram coletados **16 dias** depois de lançados, a sessão foi suspensa e retomada, e os agentes continuaram de onde tinham parado. Eles trabalharam por cerca de 40 minutos cada; os outros 16 dias foram uma sessão que nunca fechou. Nada vazou, mas também não havia ninguém esperando por aquele resultado, o que significa que ele não era gate de nada.

Se você lançar trabalho em background, diga na mesma mensagem o que você vai fazer com o resultado e quando.

## Re-review: continue o agente, não faça um novo dispatch

| Situação | Faça isto |
|---|---|
| Primeira passada num artefato | dispatch novo |
| Segunda, terceira passada no **mesmo** artefato | **continue o agente vivo** (`SendMessage`) |

Um dispatch novo relê o artefato do zero e não tem memória do que já sinalizou. Uma continuação custa uma fração e o reviewer ainda lembra dos próprios achados, que é exatamente o que um re-review precisa.

Medido: um spec reviewer rodou **três vezes na mesma spec em 12 minutos**, cada uma um dispatch novo no modelo caro, ~57k tokens por passada. Duas dessas três eram continuações fantasiadas de dispatch.

## Teto de concorrência

Mantenha uma wave numa dúzia de agentes. Além disso, eles disputam os mesmos arquivos e você gasta mais tempo reconciliando do que economizou. Se uma wave quer ser grande, geralmente são duas waves.

Se você limitar cobertura, top-N, sem retry, amostragem, **diga o que você deixou de fora**. Truncamento silencioso lê como "cobri tudo" quando não cobriu.

## Diversidade supera redundância

Cinco cópias do mesmo reviewer encontram a mesma coisa cinco vezes. Reviewers com **lentes diferentes**, correção, segurança, testes, performance, encontram cinco coisas diferentes pelo mesmo custo. Quando a fase de review de uma wave faz fan-out, faça fan-out por lente.

Um especialista estreito e barato muitas vezes supera um amplo e caro: uma passada focada em segurança pode custar um décimo de uma code review completa e pegar o que a review completa estruturalmente não consegue.

## Memória de agente

Um agente cujo frontmatter declara `memory:` tem um caderno duradouro entre execuções. O escopo decide onde ele fica: `memory: project` escreve em `.claude/agent-memory/<agent>/`, versionado e revisado com o PR como qualquer outro arquivo; `memory: user` escreve em `~/.claude/agent-memory/<agent>/`, pessoal e compartilhado por todo projeto na máquina; `memory: local` escreve em `.claude/agent-memory-local/<agent>/`, específico do projeto mas ignorado pelo git. Declará-lo não é usá-lo, o agente precisa escolher escrever.

Vale a pena persistir: convenções que o agente rederiva toda execução, pegadinhas que já morderam uma vez, a forma da área que ele possui. **Não** vale a pena persistir: qualquer coisa relegível do repositório num único grep (veja "refazível supera armazenado" no documento de contexto).

Quando você despachar um especialista de visita recorrente, diga a ele para checar a própria memória primeiro e acrescentar o que aprendeu. Do contrário a pasta fica vazia e a configuração é decoração.

## Formato de custo (ordem de grandeza, de execuções reais)

| Tipo de agente | Chamadas de tool / execução | Nota |
|---|---:|---|
| Especialista estreito (segurança, camada única) | ~15–20 | passada útil mais barata |
| Especialista de stack (implementa na sua camada) | ~45 | já conhece as convenções |
| Code review completa | ~58 | ampla por design |
| **General-purpose, sem especialista de stack** | **~122** | redescobre o repositório toda execução |

Essa última linha é o preço de um agente faltando no plugin de stack. Se você a vir, a correção é escrever o especialista, não continuar pagando.
