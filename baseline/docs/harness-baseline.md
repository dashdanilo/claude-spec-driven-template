# Baseline do harness, os números a bater

Medições de referência para o `/harness-report`. Sem uma baseline um relatório é um
número sem opinião; este arquivo é o que o transforma num veredito.

## De onde vieram

Medido em 03/08/2026 a partir das transcrições de um projeto real rodando este
template: **22 sessões, 54 dispatches de subagente, ~11,5M tokens**. Não é uma
simulação nem uma meta tirada da intuição, é o que o harness de fato fez antes
das correções listadas abaixo.

## A baseline

| métrica | medido | o que significa | direção boa |
|---|---:|---|:---:|
| **Edit delegado** | **29%** | 777 chamadas de `Edit` na thread principal contra 316 em especialistas, enquanto `Grep`/`Glob` foram 100% delegadas, a exploração estava sendo delegada e a implementação não, exatamente ao contrário | ↑ |
| **Participação de tokens da thread principal** | **71%** | 8,19M de 11,5M, num sistema cujo próprio `context-engineering.md` diz para manter a thread principal magra | ↓ |
| **Dispatches por mensagem** | **1,0** | 54 de 54 saíram um por mensagem, então nenhum plano de wave chegou a fazer fan-out | ↑ |
| Execuções de `/orchestrate` | **2** | contra 729 prompts humanos livres, o pipeline foi executado na mão | ↑ |
| Dispatches não atribuídos | **77%** | `log-agent.sh` registrou `agent=?` em 183 de 238 eventos | ↓ |
| Agentes em background não coletados | **2** | deixados abertos por 16 dias numa sessão suspensa | 0 |

## O que mudou depois disso, e o que isso significa para ler um novo relatório

Entre a baseline e agora, quatro correções foram aplicadas. **Nenhuma delas foi
remedida** — são hipóteses com raciocínio por trás, não resultados verificados.
Ler um relatório novo é como elas são julgadas:

| mudança | a afirmação que faz | o número que a confirmaria |
|---|---|---|
| `rules/delegation.md` (sempre carregada) | declarar a regra aumenta a delegação | Edit delegado bem acima de 29% |
| `/orchestrate` Step 3 reescrito por wave | as waves de fato fazem fan-out | dispatches por mensagem acima de 1,0 |
| `/orchestrate` Step 0 + matriz classe-para-gates | menos cerimônia significa que o comando é mais usado | execuções de `/orchestrate` acima de 2 |
| `log-agent.sh` lendo a transcrição do subagente | dispatches se tornam atribuíveis | não atribuídos perto de 0 |

A possibilidade honesta é que o número de delegação **não se mova**. A regra
já existia dentro do `/orchestrate` antes de ser promovida a regra sempre
carregada, e os 29% foram medidos com ela em vigor. Se um relatório novo ainda
mostrar cerca de 29%, a conclusão é que prosa não resolve isso e o próximo
passo é um mecanismo diferente, não uma frase melhor.

## Hipóteses importadas, não nossas, não medidas aqui

Números pelos quais este harness agora age que vieram do **benchmark de outra pessoa**. Eles são sinalizados para que um leitor futuro saiba quais números são ganhos e quais são emprestados.

**~3 clusters coesos, 5-7 tarefas cada** — a regra de agrupamento no `/orchestrate` Step 1 e no `/wave`.

| fonte | [Tech Leads Club](https://agent-skills.techleads.club/tlc-spec-driven/), um épico Stripe de 18 tarefas |
|---|---|
| método | uma base de código, uma execução por arquitetura, quatro arquiteturas |
| o que mostrou | um agente por tarefa é o pior em todos os eixos (25M tokens, 43m, 0,81); ~3 clusters é o melhor (10,5M, 18m, 0,95) e termina com 26% da janela em vez de 74% |
| o que é sólido | a **forma**, granularidade destrói qualidade, e mais workers pode deixar a thread principal mais gorda porque todo resumo volta para ela |
| o que não é | o **número**. n=1 por célula, e os próprios autores chamam a diferença de qualidade 0,93 vs 0,95 de estatisticamente indistinguível |

**O que confirmaria ou refutaria isso aqui:** rode o `/orchestrate` numa spec real de tamanho aproximado a esse e compare um `/harness-report` contra as linhas acima. As cifras que importam são tokens, tempo de relógio e quanto da janela resta no final, esse último é a afirmação de fato, já que o custo em tokens em 18 tarefas é neutro.

**Por que adotar antes de medir.** Nossa própria baseline mostra a falha oposta: 1,0 dispatch por mensagem e 29% de `Edit` delegado, o que significa que estamos perto da linha *inline* enquanto o `/orchestrate` como estava escrito teria produzido a linha *por tarefa*. As duas direções estão erradas e a correção aponta para o mesmo lado, então a forma vale a pena ser adotada agora. Se nossos próprios números caírem em outro lugar, o número muda e a forma permanece.

## 09/09/2026 — o instrumento estava quebrado; nenhum relatório antes desta data é utilizável

<!-- instrument-epoch: 2026-09-09 -->
<!-- harness-report.sh reads this marker to know where "current" data starts;
     agent-log.txt lines timestamped before it are excluded from headline
     stats and reported separately, with the reason. If a future fix
     invalidates everything before it the same way, add another
     `instrument-epoch:` marker in that section — the script takes the
     latest one it finds, so this file is the only place that needs editing. -->


A primeira tentativa de remedir as quatro afirmações acima descobriu que os dois
hooks que produzem os dados estavam errados de três formas. As três foram
pegas capturando payloads reais de hooks e comparando contra o que os hooks
registraram, numa única sessão neste repositório.

| bug | efeito nos números | direção |
|---|---|:---:|
| `log-edit.sh` inferia a thread a partir de `transcript_path`, que aponta para a sessão **principal** mesmo dentro de um subagente | toda edição de especialista contava como edição da thread principal; uma sessão com dois dispatches ativos do `implementer` reportou **`DELEGATED 0%`** | subestima delegação |
| `log-agent.sh` somava só `input_tokens + output_tokens` | um dispatch que criou 20.347 tokens de cache e leu mais 18.592 registrou **`tokens=169`**, ~120x abaixo | subestima o custo do subagente |
| `log-agent.sh` escolhia a transcrição do subagente pelo **mtime** mais novo | numa wave paralela cada `SubagentStop` resolvia para o mesmo arquivo, então N agentes produziam N linhas carregando a identidade e o custo do último | destrói a atribuição justamente no caso de wave |

Os três estão corrigidos. Verificado em produção: dois subagentes despachados
na mesma mensagem, um segundo de diferença, foram atribuídos aos seus próprios
tipos com seus próprios custos e zero `approx=1`; e o `.claude/tool-log.txt`
registrou o mesmo `implementer` como `main` às 03:13:34 e como `sub` às
03:13:45, através da edição que consolidou a correção.

**O que isso significa para as quatro afirmações na tabela acima.** Nenhuma
delas foi julgada ainda. A linha de delegação em particular não pode ser lida
de nenhum relatório produzido antes de hoje: o detector respondia `main`
independente da verdade, então uma porcentagem baixa medida com ele é
evidência sobre o detector e mais nada. A baseline de 29% em si sobrevive, foi
calculada a partir de transcrições em 03/08/2026, não a partir desses hooks,
mas toda comparação contra ela desde que os hooks entraram em vigor era
inválida.

**O que ainda não foi medido.** A taxa de delegação numa sessão de
implementação real. O `.claude/tool-log.txt` está vazio em todo checkout do
njord, porque os hooks nunca foram registrados lá, o harness nunca foi
adotado num repositório enquanto trabalho de feature real corria através dele.
Essa execução ainda é o item aberto, e agora é a *primeira* que pode produzir
um número que vale a pena ler.

## 10/09/2026 — A/B: o driver atual contra o que ele substituiu

A primeira execução instrumentada corretamente, e a primeira comparação real. Mesma
spec (16 tarefas de teste unitário para helpers puros no njord-back), mesmos 16
alvos, mesma baseline (14 suítes / 190 testes), mesmo instrumento fixo. Uma
variável mudou: o driver. A execução 1 usou a skill `orchestrate` atual (132
linhas). A execução 2 usou o `commands/orchestrate.md` de 53 linhas que o
`develop` do njord-back ainda distribui.

| | execução 1 (atual) | execução 2 (antigo) | |
|---|---:|---:|---|
| tarefas entregues | 16 | 16 | |
| dispatches | 8 | 53 | 6,6x |
| tokens novos | 1.776.741 | 7.708.367 | **4,34x** |
| leituras de cache | 26,3M | 68,4M | 2,6x |
| tokens de implementação por tarefa | ~52k | ~164k | 3,2x |
| testes produzidos | 220 | 548 | 2,5x |
| findings de produção | 2 | 17 | |

**Onde foi o dinheiro do driver antigo:** `code-reviewer` 40,8%, implementação
34,0%, `tester` 23,9%. O `tester` não escreveu **nada em 16 de 16 dispatches**,
a cada vez ele auditou a cobertura, não achou lacuna, e retornou. Sem uma
matriz classe-para-gates o driver antigo o despacha até em tarefas cujo
entregável é um arquivo de teste. Esse desperdício sozinho custou mais do que
a execução 1 inteira.

**Contra a tabela de afirmações acima.** Dispatches por mensagem: a execução 1
enviou sua wave três-em-um, o primeiro fan-out registrado, confirmado. Dispatches
não atribuídos: 0% nas duas execuções, confirmado. Edit delegado: a execução 1
mediu 92% (37 de 40), confirmado na direção mas fracamente, porque toda tarefa
criou um arquivo novo, a classe mais fácil possível de delegar. Os 100% da
execução 2 são um artefato (veja abaixo).

**Contra a hipótese importada da TLC.** A implementação sozinha custou 3,2x por
tarefa sob um-dispatch-por-tarefa, contra o ~2,4x da TLC entre as mesmas duas
formas. Base de código diferente, trabalho diferente, ferramenta diferente, a
proporção se reproduziu. A forma permanece estabelecida; o número agora é
nosso, não emprestado.

**Um segundo efeito que ninguém tinha medido: coerência.** Os 16 arquivos da
execução 2 vieram de 16 contextos independentes, e a review da branch listou
cinco marcadores de bug conhecido diferentes, dois idiomas em títulos de teste
e três estilos de nomenclatura de fixture. A execução 1 produziu os mesmos 16
arquivos a partir de três clusters com uma convenção só. Coesão compra
consistência, não só orçamento.

**O que o A/B não prova.**
- A execução 2 produziu mais testes e mais findings, e a causa principal foi o
  orquestrador: a partir da sua quinta tarefa, o briefing de implementação
  exigia provar que asserções centrais matavam uma mutação, uma instrução que
  a execução 1 nunca teve. O viés favorece o driver antigo, e ele ainda custou
  4,34x.
- A delegação da execução 2 lê 100% porque o orquestrador editou os próprios
  documentos através do `Bash`, que o `log-edit.sh` não vê. As duas
  porcentagens não são comparáveis. Buraco de instrumentação, **fechado em
  12/09/2026** — veja essa seção datada abaixo para o que mudou e por que todo
  número neste arquivo antecede uma definição mais ampla de "edição" do que
  qualquer relatório produzido depois dessa data.
- Dois dispatches da execução 2 foram mortos por um rate limit e nunca
  dispararam `SubagentStop`; o log subestima a execução 2 em pelo menos 97.478
  tokens.
- n=1 por driver.

**Decisão registrada.** O driver atual é o que deve ser adotado. O que a
execução 2 fez melhor, a review por tarefa encontrou lacunas reais de asserção
em três das suas quatro primeiras tarefas, e a exigência de mutação as
impediu, é portado para ele em vez de mantido mantendo o driver antigo: review
por cluster, testabilidade por falsificação no handoff de implementação, uma
checklist de variação de ambiente para a review de branch, e nenhum agente de
verificação escrevendo num arquivo rastreado. Projeção, não medição: ~2,3M
para a mesma spec, ainda ~3,3x abaixo do driver antigo.

## 12/09/2026 — o ponto cego de escrita via Bash está fechado; a série de delegação tem um novo denominador

O `log-edit.sh` só era registrado em `PreToolUse` para
`Edit|Write|MultiEdit|NotebookEdit`. Uma escrita feita através do `Bash`, um
redirecionamento, `sed -i`, `tee`, `cp`, `mv`, era invisível para ele. O A/B de
10/09/2026 acima pegou isso em flagrante: o orquestrador da execução 2 editou
seus próprios documentos rastreados através do `Bash` e reportou **100%
delegado**, o que nunca foi um número real, só um ponto cego lendo como
perfeição. O erro é otimista, a piora direção para um relatório cujo trabalho
inteiro é "isso está sendo usado como projetado."

O `log-edit.sh` agora também roda em `PreToolUse`/`Bash`. Ele recupera uma
escrita a partir do comando com um pequeno lexer em nível de caractere (não um
parser de shell completo, rastreia estado de aspas, reconhece `>`/`>>`, `sed
-i`, `tee`, `cp`, `mv`, e explicitamente pula `2>`/`&>`/`>&` e `[[ ]]`/`(( ))`),
e registra o alvo só quando ele resolve **dentro do repositório**, `/dev/null`,
`/tmp`, o scratchpad da sessão e qualquer outra coisa fora do projeto são
descartados silenciosamente, por uma regra só em vez de uma lista de exclusão
crescente. Um alvo que ele não consegue resolver para um caminho literal (uma
variável de shell, uma substituição de comando) também não é descartado: é
registrado com `path` igual a `?`, porque a thread ainda é conhecida e a
contagem de delegação ainda precisa dela, só o detalhamento por extensão perde
essa linha, e o `harness-report.sh` diz quantas descartou em vez de fazer isso
silenciosamente.

**Isso muda o denominador, não só o detector.** Toda porcentagem de delegação
neste arquivo, os 29% da baseline, o par 92%/100% do A/B acima, foi calculada
só sobre Edit/Write/MultiEdit/NotebookEdit. Uma porcentagem medida depois de
12/09/2026 também conta escritas recuperadas via Bash, então ela pode se mover
por um motivo que não tem nada a ver com quanto trabalho de fato é delegado: o
conjunto do que está sendo contado ficou maior. **Não compare um número de
delegação anterior a 12/09/2026 contra um posterior a essa data como se fossem
a mesma série.** Leia cada um do seu próprio lado dessa data; uma subida ou
queda através dela ainda não é evidência de nada.

**O que ainda não foi medido.** Quanto da delegação real ficava sem contar
antes porque acontecia via Bash, isso exige um relatório de uma sessão de
implementação real rodada depois desse fix, comparado contra um rodado antes
dele no mesmo tipo de trabalho. Esse par ainda não existe.

## 12/09/2026 — os totais de tokens de subagente estavam duplicados; o resumo agora só conta a métrica confiável

O fallback de grau 3 do `log-agent.sh` (sem `agent_transcript_path`, sem
`agent_id` no payload, só clientes antigos) escolhe a transcrição mais nova
por mtime no diretório `subagents/` da sessão e sempre foi marcado `approx=1`
por esse motivo. O que o comentário não previa: numa wave paralela, todo
`SubagentStop` daquela wave resolve para o **mesmo** arquivo mais novo, e o
grau 3 copiava as métricas daquele arquivo em toda linha, não só na primeira.
As linhas não só chutavam errado, elas somavam os tokens da mesma transcrição
uma vez por subagente na wave.

Medido no próprio `.claude/agent-log.txt` desta máquina (135 linhas) antes do
fix: 22 linhas carregavam `approx=1`, todas com o `agent=` correto (essa parte
vem direto do payload, não do arquivo chutado, então a atribuição nunca foi o
problema, as métricas eram). Três dessas linhas compartilhavam
`tokens=486296`, duas compartilhavam `tokens=293605`, duas compartilhavam
`tokens=115571`, seis linhas, três transcrições, cobradas como seis. Total de
tokens de subagente reportado: 11.718.022. Desse total, 4.830.845 (41%)
estavam em linhas `approx=1`, um número com o mesmo peso no total que qualquer
um medido, apresentado sem nenhuma diferença visual dele.

**A correção.** O `log-agent.sh` agora mantém um registro de "já cobrado"
(`.claude/.agent-log-consumed`, ignorado pelo git, indexado por sessão) e o
checa antes de o grau 3 reportar as métricas de uma transcrição. O primeiro
`SubagentStop` a chegar num dado arquivo numa sessão recebe seus tokens/cache/duração/tools
reais; todo posterior que resolve para o *mesmo* arquivo recebe `agent=`
(ainda confiável) e `dup=1`, sem nenhum campo de métrica, um número faltando,
não o número de outra pessoa. O `harness-report.sh` agora exclui os tokens de
toda linha `approx=1` do total do resumo de "tokens de subagente" (uma linha
`dup=1`, não tendo campo `tokens=`, já contribui com 0) e reporta a fração
aproximada na própria linha, veja a saída do próprio relatório para o formato.

**Isso muda a comparabilidade de novo, do mesmo jeito que a entrada de
delegação de 12/09/2026 acima faz para as edições.** Toda cifra de "tokens de
subagente" neste arquivo, os 11,5M na baseline original, os 1.776.741 /
7.708.367 no A/B, foi lida de um total que misturava métrica confiável e
(às vezes duplicada) aproximada sem jeito de distinguir depois do fato. Um
total de tokens medido depois desse fix só conta linhas com métrica real e
atribuída de forma única; um total medido antes dele não conta, e as duas não
são a mesma série. Leia cada um do seu próprio lado dessa data.

**O que ainda não foi medido.** Se o grau 3 ainda dispara contra um cliente
Claude Code atual, o fallback existe para clientes antigos que omitem
`agent_transcript_path`/`agent_id`, e se o cliente atual sempre envia um dos
dois, esse caminho inteiro (e o bug nele) já pode estar dormente na prática.
Isso exige checar um payload real de uma sessão atual, não um log de hook
depois do fato.

## 23/09/2026 - protocolo A/B para o /lean contra o /orchestrate (ainda não executado)

O `/lean` (`baseline/skills/lean/SKILL.md`) existe porque scaffolding por
tarefa é uma hipótese sobre custo, não um fato definido, uma vez que o modelo
seja forte o suficiente para sequenciar seu próprio trabalho sem um checkbox
por passo. Esta seção é o protocolo para julgar essa hipótese, não um
resultado: nenhuma execução aconteceu ainda, e os números abaixo estão
deliberadamente ausentes em vez de chutados.

**Design.** Uma feature real, do tamanho que o contexto de um único
especialista aguenta (a mesma classe de tamanho que a tabela "Quando usar
qual" do `/lean` nomeia como seu ajuste), construída duas vezes a partir do
mesmo commit de partida com o mesmo modelo: uma vez pelo `/lean`, uma vez pelo
`/orchestrate`. Mesmo critério de aceitação para as duas execuções, então a
comparação é o driver, não o escopo.

**O que ler do `/harness-report` depois de cada execução:**

- **Tokens.** Total, e a divisão entre thread principal e subagente, o mesmo
  detalhamento que o A/B de 10/09/2026 usou para os drivers antigo e atual do
  `orchestrate`.
- **Dispatches.** Contagem, e dispatches por mensagem (o `/lean` tem exatamente
  um dispatch de build e um de verify por construção; a contagem do
  `/orchestrate` depende de quantos clusters ele planeja).
- **Participação de tokens da thread principal.** O número que a própria
  baseline deste arquivo (71%) e a regra de delegação foram escritas para
  mover.
- **Tempo de relógio.** Do início à abertura do PR, nas duas execuções.
- **Retrabalho.** Quantas vezes o gate ficou vermelho antes de ficar verde de
  forma estável, e quantas rodadas de review o `code-reviewer` precisou para
  chegar a zero blockers abertos. Esse é o número que mostraria se a estrutura
  mais leve do `/lean` de fato custa mais correções depois, do jeito que
  um-agente-por-tarefa custou na hipótese importada da TLC acima.

**Por que isso é um protocolo separado e não uma reexecução de 10/09/2026.**
Aquele A/B comparou duas versões do mesmo driver (o `orchestrate` atual contra
o de 53 linhas que ele substituiu) em 16 tarefas de teste unitário, n=1. Ele
não diz nada sobre o `/lean`, que ainda não existia, e seus próprios números
não são comparáveis a ele além disso (veja as entradas de 12/09/2026 acima
sobre os denominadores de delegação e total de tokens mudando). Uma
comparação `/lean` vs `/orchestrate` precisa da sua própria execução, num
trabalho do tamanho para o qual o `/lean` afirma servir, lida contra este
protocolo, não encaixada na tabela existente.

## Lendo um relatório honestamente

- **Uma amostra pequena não é uma tendência.** Um punhado de edições numa
  sessão não diz nada. Compare entre sessões, e prefira a direção ao valor.
- **`thread unknown` não tem custo zero.** A detecção de thread é uma
  heurística sobre o payload do hook. Se os desconhecidos dominam, o relatório
  está descrevendo o detector, não o comportamento.
- **Um número bom numa sessão que não fez implementação nenhuma não significa
  nada.** Uma sessão que só leu arquivos não delega nada porque não havia nada
  para delegar.
- Os logs são ignorados pelo git e por checkout. Eles medem *esta* cópia de
  trabalho, não o time.

## Atualizando este arquivo

Quando uma medição for feita ampla o suficiente para substituir a baseline,
adicione uma nova seção datada em vez de editar a tabela acima. O rastro do
que o harness costumava fazer é o ponto, o mesmo motivo pelo qual o
`.claude/rules/harness/adr.md` torna as decisões somente para acréscimo.
