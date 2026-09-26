# LEARN.md

Um curso guiado pela estrutura de IA deste repositório. Leia [`README.md`](./README.md) primeiro para a visão geral. Este arquivo vai mais a fundo.

## Sumário

- [Capítulo 1: O custo do contexto](#capítulo-1-o-custo-do-contexto)
- [Capítulo 2: Os cinco subsistemas](#capítulo-2-os-cinco-subsistemas)
- [Capítulo 3: Instruções em camadas](#capítulo-3-instruções-em-camadas)
- [Capítulo 4: Skill vs rule vs agent](#capítulo-4-skill-vs-rule-vs-agent)
- [Capítulo 5: Subagents e contexto isolado](#capítulo-5-subagents-e-contexto-isolado)
- [Capítulo 6: Memória de subagent](#capítulo-6-memória-de-subagent)
- [Capítulo 7: Conhecimento sobre bibliotecas](#capítulo-7-conhecimento-sobre-bibliotecas)
- [Capítulo 8: Desenvolvimento guiado por spec](#capítulo-8-desenvolvimento-guiado-por-spec)
- [Capítulo 9: Registros de Decisão de Arquitetura](#capítulo-9-registros-de-decisão-de-arquitetura)
- [Capítulo 10: Hooks e eventos de ciclo de vida](#capítulo-10-hooks-e-eventos-de-ciclo-de-vida)
- [Capítulo 11: Greenfield vs brownfield](#capítulo-11-greenfield-vs-brownfield)
- [Capítulo 12: Erros comuns](#capítulo-12-erros-comuns)

---

## Capítulo 1: O custo do contexto

Toda sessão do Claude Code tem um custo fixo antes de você digitar a primeira mensagem: definições de tool, system prompt e instruções de nível de projeto (`CLAUDE.md`) carregam na janela de contexto. Isso soma milhares de tokens.

A implicação: o que carrega sempre precisa ser pequeno. O que é detalhado precisa carregar sob demanda.

Essa única percepção conduz toda a estrutura deste template:

- a raiz do `CLAUDE.md` é curta
- rules têm escopo por path
- docs só carregam quando uma skill os referencia
- subagents trabalham em janelas de contexto isoladas

Internalize essa regra e o resto da estrutura faz sentido.

---

## Capítulo 2: Os cinco subsistemas

O diretório `.claude/` tem cinco subsistemas distintos:

1. **Settings** (`settings.json`) define permissões e registros de hook
2. **Skills** (`skills/`) são workflows reusáveis carregados por match de descrição
3. **Agents** (`agents/`) são especialistas com contexto isolado
4. **Rules** (`rules/`) são convenções com escopo que carregam automaticamente por glob
5. **Hooks** (`hooks/`) são scripts disparados por eventos do ciclo de vida das tools

Mais um diretório não oficial mas extremamente útil: **Docs** (`docs/`), que guarda conhecimento consultado sob demanda.

A maioria dos projetos usa todos os seis. Cada um tem um custo e um gatilho diferente.

| Subsistema | Quando carrega | Custo de contexto |
|---|---|---|
| `settings.json` | Sempre, no início da sessão | Mínimo |
| `skills/` | Quando a descrição combina com a task | Carrega só quando ativa |
| `agents/` | Quando invocado ou auto-delegado | Isolado, não poluí a principal |
| `rules/` | Quando o path combina com o glob | Carrega quando relevante |
| `hooks/` | Em evento do ciclo de vida | Zero |
| `docs/` | Quando uma skill referencia explicitamente | Zero até ser lido |

---

## Capítulo 3: Instruções em camadas

Existem quatro lugares onde instruções podem viver, na ordem de como carregam:

### Camada 0: `AGENTS.md`

A fonte de verdade compartilhada. Lida por todos os agents de codificação de IA que suportam a convenção AGENTS.md (Claude Code, Codex, Cursor, Gemini CLI, GitHub Copilot, e outros). Conteúdo:

- Stack técnica (uma linha por item)
- Comandos de build e test
- Mapa de diretórios de nível superior
- Convenções que se aplicam em todo lugar
- Workflow de feature
- Inegociáveis
- Ponteiros para onde a informação detalhada vive

O que NÃO vai aqui: extras específicos de ferramenta, explicações longas, docs de biblioteca, exemplos com mais de 20 linhas.

### Camada 1: `CLAUDE.md` da raiz (como stub)

Carrega no início de toda sessão do Claude Code. Neste template, `CLAUDE.md` é um **stub** que aponta para `AGENTS.md` em busca do conteúdo compartilhado, e depois só adiciona o que é específico do Claude Code:

- Quais skills, subagents, hooks e rules este projeto entrega
- Onde vivem os CLAUDE.md aninhados
- Onde vão os overrides pessoais (`CLAUDE.local.md`)

O padrão de stub remove duplicação: você atualiza a stack em `AGENTS.md`, todos os agents veem isso, e o `CLAUDE.md` nunca sai de sincronia porque não é dono daquele conteúdo.

### Camada 2: `CLAUDE.md` aninhado

Um `CLAUDE.md` colocado dentro de uma pasta carrega automaticamente quando o Claude navega naquela pasta. Invisível quando o Claude está em outro lugar. **Arquivos CLAUDE.md aninhados NÃO são stubs**: eles têm conteúdo completo, porque descrevem convenções específicas daquela pasta que nenhum outro arquivo é dono.

Use para convenções específicas dessa camada:

- "esta pasta é server-side, nunca importe do client"
- "arquivos esperados aqui: foo.ts, bar.ts, cada um com .test.ts"
- "a fonte de verdade é a spec em /specs/.../spec.md"

### Camada 3: Rules com escopo de path

Em `baseline/rules/`, rules com `paths:` no frontmatter carregam só quando o glob combina com o arquivo que o Claude está tocando.

```markdown
---
paths: "**/*.{tsx,jsx}"
---

# Convenções de React

- Só exports nomeados
- Interface de props acima do componente
- Sem default exports
```

Quando escolher CLAUDE.md aninhado versus rule?

- **CLAUDE.md aninhado** quando a convenção está amarrada a uma pasta e vive ao lado do código
- **Rule** quando a convenção se aplica a várias pastas por tipo de arquivo

---

## Capítulo 4: Skill vs rule vs agent

Três coisas que parecem parecidas mas fazem trabalhos diferentes.

### Rule

- **O que é:** texto de orientação com escopo
- **Gatilho:** o path combina com o glob
- **Saída:** o Claude lê como contexto
- **Use quando:** for uma convenção que precisa ser lembrada ao editar certos arquivos

### Skill

- **O que é:** workflow reusável
- **Gatilho:** a descrição combina com a task em questão
- **Saída:** o Claude segue o workflow
- **Use quando:** for um processo repetido, de vários passos, entre sessões

### Agent (subagent)

- **O que é:** especialista com contexto isolado
- **Gatilho:** invocação explícita ou auto-delegação via descrição
- **Saída:** retorna um resumo final; o trabalho intermediário fica isolado
- **Use quando:** for investigação profunda, review, ou task que não deve poluir o contexto principal

Um erro comum é usar uma rule para o que deveria ser uma skill. Se você se pegar escrevendo "quando fizer X, siga estes 7 passos" numa rule, isso deveria ser uma skill.

---

## Capítulo 5: Subagents e contexto isolado

Um subagent roda na própria janela de contexto, do zero. O orquestrador entrega um prompt, o subagent trabalha (lê arquivos, roda tools, raciocina), e só a mensagem final volta para o orquestrador.

Isso é poderoso porque:

- Code review pode ler 50 arquivos sem poluir sua sessão
- Pesquisa sobre uma biblioteca pode explorar docs sem preencher seu contexto
- Subagents paralelos podem rodar ao mesmo tempo (auditoria de segurança + code review + checagem de performance)

O frontmatter:

```markdown
---
name: code-reviewer
description: Reviews code against the plan. Use PROACTIVELY after each task.
tools: Read, Grep, Glob, Bash
model: sonnet
memory: project
---
You are a senior code reviewer...
```

Campos chave:

- **`name`** é o identificador
- **`description`** é o gatilho de auto-delegação; escreva como uma condição de uso
- **`tools`** restringe o que o subagent pode fazer (menor = mais seguro)
- **`model`** escolhe o tier de modelo; use `opus` para review/pesquisa, `sonnet` ou `haiku` para execução
- **`memory`** habilita memória persistente (veja o próximo capítulo)

### A convenção "Use PROACTIVELY"

O Claude auto-delega com base na `description`. Para empurrar a delegação automática sem que você peça, a convenção da comunidade é escrever descrições como:

- "Use PROACTIVELY after each task is implemented"
- "Use immediately when reviewing code changes"
- "Use when investigating an unfamiliar library"

Sem essas frases, o Claude tende a esperar um pedido explícito.

---

## Capítulo 6: Memória de subagent

Introduzido no Claude Code v2.1.33, o campo de frontmatter `memory:` dá a um subagent um diretório persistente:

```markdown
---
memory: user        # ~/.claude/agent-memory/<name>/ (pessoal, compartilhado entre todo projeto)
# OU
memory: project     # .claude/agent-memory/<name>/ (versionado, compartilhável via controle de versão)
# OU
memory: local       # .claude/agent-memory-local/<name>/ (específico do projeto, no gitignore)
---
```

As primeiras 200 linhas do `MEMORY.md` daquele diretório são injetadas automaticamente no system prompt do subagent a cada invocação. O subagent tem as tools Read, Write e Edit habilitadas para gerenciar as próprias notas.

`memory: project` é o escopo que todo agent do baseline usa: o caderno cai no diff da branch de feature e é revisado com o PR como qualquer outro arquivo, então um colega que nunca rodou o agent ainda vê o que ele aprendeu. Só `memory: local` fica no gitignore; recorra a ele quando as notas forem de fato amarradas a uma máquina e enganariam um colega de time.

Isso é persistência real. Um subagent `researcher` que investigou cinco bibliotecas na semana passada vai lembrar as pegadinhas nesta semana.

### A pegadinha

Cada subagent tem sua própria memória. O `MEMORY.md` do `code-reviewer` é invisível para o `security-auditor`. Conhecimento não flui entre subagents.

Se você precisa de memória compartilhada entre subagents, olhe plugins como `hindsight-memory`. Para a maioria dos casos, memória isolada é suficiente.

### Quando memória vale ouro

- Um `researcher` que investiga muitas bibliotecas (acumula expertise profunda)
- Um `code-reviewer` que aprende anti-patterns específicos do projeto
- Um `security-auditor` que constrói um catálogo de vulnerabilidades passadas

### Quando memória é ruído

- Subagents invocados uma vez ou raramente
- Subagents cujo contexto está totalmente capturado na spec ou no plan que leem
- Qualquer caso em que memória desatualizada enganaria mais do que ajudaria

---

## Capítulo 7: Conhecimento sobre bibliotecas

É aqui que a maioria dos projetos quebra: eles despejam todo o conhecimento de biblioteca no `CLAUDE.md` e pagam o custo de contexto em toda sessão.

A resposta certa: quatro camadas, do barato ao detalhado.

### Camada 1: Uma linha no `CLAUDE.md`

```
## Tech stack
- <Seu framework> + <Sua linguagem>
- <Sua abordagem de estilo>
- <Seu gerenciador de pacotes> + <Seu test runner>
- <Seu banco de dados e ORM>
```

Só o nome e o papel. Sem detalhes.

### Camada 2: Rules de convenção em `baseline/rules/`

Para convenções amarradas a uma biblioteca que se aplicam pelo codebase inteiro:

```markdown
---
paths: "**/*.{tsx,jsx}"
---

# Convenções do framework de UI
- Use design tokens, não valores arbitrários
- Siga os padrões de componente já existentes
```

### Camada 3: Doc de biblioteca específico do projeto em `baseline/docs/libs/`

Não a doc oficial. O subconjunto que você usa, com suas pegadinhas:

```markdown
# Provedor de pagamento

## Como autenticamos
- Chaves de produção ficam na camada de orquestração, nunca no código da aplicação
- Chaves de teste em .env.local

## Endpoints que usamos
- POST /v1/payment_intents
- POST /v1/webhooks (verificação de assinatura exigida)

## Pegadinhas
- Idempotency keys exigidas para retries
- Webhooks de teste precisam de um túnel (ex.: ngrok)
```

### Camada 4: Memória de subagent para acumular descobertas

Um subagent `researcher` com `memory: user` constrói expertise entre sessões.

### Quando usar qual

| Você precisa saber... | Camada |
|---|---|
| Qual é a stack? | `CLAUDE.md` |
| Que convenção de nomenclatura se aplica a arquivos .tsx? | `baseline/rules/` |
| Como usamos um serviço externo específico? | `baseline/docs/libs/<name>.md` |
| Que pegadinhas já encontrei com essa lib antes? | memória do subagent `researcher` |
| Referência completa da API oficial? | Context7 MCP, não duplique |

---

## Capítulo 8: Desenvolvimento guiado por spec

A pasta `specs/` segue um padrão de três arquivos que separa O QUÊ, O COMO em nível alto, e o COMO em nível de execução. Cada feature é uma pasta com `spec.md`, `plan.md` e `tasks.md`.

### Os três arquivos

```
specs/YYYY-MM-DD-feature-slug/
├── spec.md      # O QUÊ + POR QUÊ (fonte de verdade, imutável após aprovação)
├── plan.md      # O COMO em nível alto (arquitetura, tecnologia, fases)
└── tasks.md     # O COMO em nível de execução (checkboxes atômicos, TDD)
```

Isso espelha para onde Kiro (Amazon), Spec Kit (GitHub) e Junie (JetBrains) convergiram. Funciona porque os três arquivos têm propósitos, audiências e frequências de atualização diferentes:

| Arquivo | Responde | Frequência de atualização |
|---|---|---|
| `spec.md` | "O que estamos construindo? Por quê?" | Rara, só se a própria feature mudar |
| `plan.md` | "Qual é a abordagem técnica? Quais fases?" | Ocasional, se a estratégia mudar |
| `tasks.md` | "Onde eu parei? O que vem a seguir?" | Constante, atualizado depois de cada task |

Se você colapsar os três num arquivo só, perde a capacidade de responder "onde eu parei?" rapidamente. O `tasks.md` sozinho responde isso: a primeira caixinha não marcada.

### O fluxo

```
1. Brainstorm no chat (skill: explore)
       ↓
2. spec.md escrito e commitado
       ↓
3. subagent spec-reviewer audita
       ↓
4. plan.md preenchido: arquitetura, escolhas de tecnologia, fases
       ↓
5. tasks.md preenchido: checkboxes atômicos com passos de TDD
       ↓
6. Executa task por task (guiado por subagent ou manual)
       ↓
7. subagent code-reviewer faz auto-gate em cada fase
       ↓
8. Faz merge quando todas as caixinhas estiverem marcadas
```

Cada passo é um gate. O próximo não acontece até o atual ser aprovado.

### Por que funciona

A maior fonte de retrabalho em desenvolvimento assistido por IA é a decisão implícita. O agent começa a codificar, faz uma suposição, e a suposição molda o design em silêncio. Dois dias depois você descobre que a suposição estava errada.

Desenvolvimento guiado por spec traz cada decisão à superfície antes do código. O brainstorm faz perguntas. A spec as registra. O plan as transforma em arquitetura. As tasks transformam arquitetura em passos atômicos. O código segue as tasks. Quando algo dá errado, você consegue rastrear até a decisão exata e corrigir.

### Onde eu parei?

A pergunta mais comum no meio de uma feature. Abra o `tasks.md`. A primeira `- [ ]` não marcada é onde você parou. Se você pausou dentro de uma task, o `Notes:` inline sob aquela task conta por quê.

Exemplo:

```markdown
- [x] Task 6: normalizar número de telefone
- [ ] Task 7: rota de API para envio de lead
   Notes: pausei aqui. O Zod v4 mudou a API de union types,
   preciso confirmar o formato com o time antes de continuar.
- [ ] Task 8: fila de retry
```

Você (ou outro agent) abre esse arquivo e sabe: task 7, o bloqueio é Zod v4, retomar quando confirmado.

### Por que parece lento no início

A fase de spec + plan custa uma ou duas horas antes de qualquer código rodar. As primeiras três ou quatro features parecem mais lentas que codificar no impulso. O ponto de equilíbrio costuma ficar por volta da quinta feature, quando as specs começam a pegar erros de design que de outro jeito iriam ao ar e precisariam ser reescritos.

### Quando NÃO usar esse fluxo

- Correções de bug triviais (typos, mudanças de label)
- Refatorações mecânicas (renomear, mover, extrair)
- Prototypes descartáveis (mas se o prototype for ao ar, rode o fluxo antes do merge)

### Dois inegociáveis

1. **A spec é a fonte de verdade.** Quando código e spec discordam, pergunte, não assuma.
2. **Teste antes do código.** Toda task em `tasks.md` começa com um teste que falha, depois o código mínimo, depois o refactor.

---

## Capítulo 9: Registros de Decisão de Arquitetura

Specs descrevem o que uma feature faz. ADRs descrevem por que o sistema tem a forma que tem. Os dois são necessários, e respondem perguntas diferentes.

Um ADR é um documento curto e imutável que captura uma única decisão significativa:

- O contexto que a forçou
- As opções consideradas
- A escolha feita
- Consequências (positivas, negativas, riscos aceitos)

Uma vez aceito, um ADR não muda. Se a decisão mudar depois, um ADR novo supera o antigo. Os dois permanecem no repo. O histórico completo do raciocínio é o valor.

### Cinco benefícios concretos

**1. Preserva contexto que desaparece.**
Seis meses a partir de agora você vai olhar para uma escolha estranha e se perguntar por quê. O ADR explica as restrições que a moldaram, restrições que talvez não sejam mais óbvias. Sem ele, alguém "corrige" a decisão e quebra algo porque não sabia por que era daquele jeito.

**2. Evita reabrir a mesma discussão.**
Alguém pergunta "por que não estamos usando Redis?" Em vez de debater do zero, você aponta para o ADR 0003 e volta ao trabalho. O custo da discussão desaba.

**3. Onboarding fica mais rápido.**
Um desenvolvedor novo lê 10 ADRs e entende o raciocínio arquitetural sem entrevistar todo mundo. Isso costuma ser a diferença entre "produtivo em duas semanas" e "produtivo em dois meses".

**4. Rastreabilidade durante falhas.**
Quando algo quebra por causa de uma decisão antiga, o ADR mostra as premissas sob as quais ela foi tomada. Você checa se as premissas ainda valem. Se não, esse é o seu conserto.

**5. Escrever o ADR expõe fragilidade.**
Muitas vezes você começa a escrever e percebe que a decisão não se sustenta. Melhor descobrir isso agora do que em produção.

### Quando escrever um

Sim, escreva um ADR quando:

- Escolher uma tecnologia central (framework, banco de dados, ORM, provedor de auth)
- Mudar o modelo de confiança ou a arquitetura
- Fixar uma restrição que vai moldar features futuras
- Decidir "NÃO vamos fazer X" quando X parece tentador

Não, não escreva um para:

- Convenções de nomenclatura (essas vão em `docs/CONVENTIONS.md` ou `baseline/rules/`)
- Escolhas triviais de biblioteca (lodash, date-fns)
- Qualquer coisa reversível num dia

### Formato

O template traz um em `docs/decisions/0001-example.md`. Estrutura:

```markdown
# NNNN - Título

**Status:** Proposed | Accepted | Superseded by NNNN
**Date:** YYYY-MM-DD
**Decider:** nome ou time

## Context
O que forçou a decisão. Restrições, problema, gatilho.

## Options considered
1. A - vantagens, desvantagens
2. B - vantagens, desvantagens

## Decision
Escolhemos X porque...

## Consequences
### Positive / Negative / Risks accepted

## Revisit when
Condições que reabririam essa decisão.
```

Numerados em sequência (0001, 0002, ...) com slugs curtos em kebab-case.

### Quatro formas de integrar ADRs com agents de IA

**1. Ler ADRs durante a exploração.**
A skill `explore` deste template lê `docs/decisions/` antes de propor opções. Decisões passadas aparecem naturalmente. Adicione ao seu CLAUDE.md: "Antes de propor arquitetura, confira `docs/decisions/` por ADRs relacionados."

**2. Reforçar durante code review.**
Adicione ao prompt do subagent `code-reviewer`: "Verifique se esta mudança não viola em silêncio nenhum ADR aceito em `docs/decisions/`." Um check que falha se torna um item do relatório.

**3. Citar em explicações.**
O subagent `researcher`, quando perguntado "por que X é desse jeito?", cita ADRs diretamente. Adicione ao prompt dele: "Ao explicar uma escolha de design já existente, procure um ADR que a documente e cite pelo número."

**4. Propor ADRs novos proativamente.**
Quando você se pegar explicando "por que fizemos X" mais de duas vezes no Slack/PRs/reviews, esse é o gatilho. Peça a um agent: "Transforme esta explicação num draft de ADR em `docs/decisions/`." Revise, numere, commite.

### Um hábito que vale construir

Se uma decisão é contestada num PR e o código vai mudar com base na discussão, escreva o ADR *primeiro*, depois aprove o PR. Isso evita "combinamos algo num chat que ninguém documentou", a fonte mais comum de deriva de decisão.

---

## Capítulo 10: Hooks e eventos de ciclo de vida

Hooks são scripts determinísticos que rodam em eventos do ciclo de vida das tools. Eles não carregam contexto, causam efeitos colaterais.

### Eventos disponíveis

| Evento | Quando dispara | Use para |
|---|---|---|
| `PreToolUse` | Antes de qualquer tool rodar | Bloquear comandos perigosos, validar input |
| `PostToolUse` | Depois que uma tool termina | Auto-formatação, lint, notificação |
| `Stop` | Quando o Claude termina o turno | Notificação de desktop, log de métrica |
| `SessionStart` | No início de uma sessão | Injetar contexto extra |
| `Notification` | Quando o Claude precisa do seu input | Alerta visual ou sonoro |

### Anatomia

Um hook é qualquer executável que lê JSON do stdin. Código de saída 0 libera, diferente de zero bloqueia (para eventos Pre).

```bash
#!/usr/bin/env bash
input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

if [[ "$command" =~ "cat .env" ]]; then
  echo "BLOCKED: cannot read .env files" >&2
  exit 1
fi

exit 0
```

Registrado em `settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "baseline/hooks/block-secrets.sh" }
        ]
      }
    ]
  }
}
```

### Bons casos de uso para hooks

- Bloquear comandos destrutivos (`rm -rf /`, `git push --force`)
- Prevenir vazamento de secret (ler `.env`, imprimir tokens)
- Auto-formatação ao escrever um arquivo
- Notificação de desktop quando uma task longa termina

### Casos de uso ruins para hooks

- Carregar contexto (use rules ou docs)
- Chamadas de rede (lentas e não confiáveis)
- Qualquer coisa que depende de estado global

---

## Capítulo 11: Greenfield vs brownfield

Os termos vêm da construção civil. **Greenfield** é terreno vazio: você começa do zero, sem restrições de trabalho anterior. **Brownfield** é terreno onde já existem construções: você precisa lidar com o que já está lá antes de conseguir construir.

Em código:

- Um repo novo no dia um é greenfield
- Quase todo projeto real um mês depois é brownfield
- Codebases legadas (anos de idade, muitas mãos, docs escassos) são brownfield extremo

Por que isso importa para agents de IA: modelos são treinados majoritariamente em código apresentado em tutoriais do tipo "veja como construir X do zero". Quando você pede para uma sessão nova adicionar uma feature, o comportamento padrão é pensar em greenfield: instalar uma lib, criar abstrações, escrever tudo do zero. Em brownfield, isso produz implementações paralelas de coisas que já existem, desvio dos padrões estabelecidos, e retrabalho lento e caro.

### A mentalidade de brownfield

Antes de qualquer código, três perguntas:

1. Isso já existe aqui?
2. Se não, qual é o análogo mais próximo e como ele está estruturado?
3. Quais convenções se aplicam à área que vou tocar?

Pular essas perguntas transforma toda task em greenfield. Segui-las mantém o codebase coerente.

### Como este template dá suporte a brownfield

Seis mecanismos trabalham juntos:

**Skill `analyze-codebase` (uma vez só)**
Quando você adota este template num projeto existente, essa skill escaneia o codebase, amostra arquivos, detecta stack e convenções, e gera docs de baseline (`CONSTITUTION.md`, `CONVENTIONS.md`, `architecture/overview.md`). Ela também gera um repo map, sempre, independente do tamanho do projeto.

**Repo map (`.claude/context/repo-map.md`)**
Um mapa pequeno e determinístico: árvore de diretórios com contagem de arquivos por pasta, entry points, locais de teste, e o bloco de comandos retirado do `AGENTS.md`, gerado por `baseline/scripts/repo-map.sh`. Ele cresce com a contagem de diretórios, não com o conteúdo dos arquivos, então fica na faixa de poucos milhares de tokens até num repo com mais de mil arquivos (medido em `docs/decisions/0003-repo-map-over-snapshot.md`). Isso substituiu um design anterior que empacotava o codebase inteiro num arquivo com o Repomix; essa abordagem chegava a megabytes num repo real, bem além de qualquer coisa legível como contexto, então agora está rebaixada a um export separado, manual e opt-in (veja abaixo) em vez de ser o padrão.

**Sem check de defasagem no repo map**
Regenerá-lo custa menos de um segundo, então o template simplesmente o regenera sempre em vez de fazer cache e classificar idade. `baseline/scripts/check-snapshot.sh` ainda existe, mas agora classifica o export manual do Repomix, e seu primeiro check é um orçamento rígido de tamanho (`too-large` acima de aproximadamente 75 mil tokens), não defasagem.

**Subagent `codebase-explorer`**
Somente leitura. Gera o repo map do zero para perguntas panorâmicas, usa grep/glob para perguntas específicas. Reporta o que leu e o que encontrou.

**Hook de `SessionStart`**
Avisa no início de uma sessão só se existir um export do Repomix no disco e ele estiver acima do orçamento de tamanho. Silencioso no resto, inclusive quando nenhum export existe, que é o caso comum agora. Nunca bloqueia.

**Skill `find-existing-first`**
Dispara imediatamente antes de criar qualquer arquivo novo. Procura sinônimos, confere padrões, reporta o que encontrou. Só segue para a criação se nada existir.

### O workflow

Adotando o template num projeto brownfield:

```
1. Clone o template no projeto
2. Rode /skill analyze-codebase (gera docs de baseline e o repo map)
3. Revise os docs gerados, resolva os TODOs, commite
4. Opcional: instale o plugin Ponytail para reforço de YAGNI entre ferramentas
5. A partir de agora, use /skill explore antes de /skill write-spec para features novas
6. O codebase-explorer roda em silêncio quando profundidade é necessária, regenerando o repo map por conta própria
```

Você não gerencia o repo map manualmente depois do passo 2. O sistema cuida disso.
Se você também quiser um export manual, de arquivo único, do Repomix para alguma outra ferramenta,
`/skill refresh-snapshot` faz isso quando pedido; é separado e opcional.

### Ferramentas externas que complementam isso

- **[Ponytail](https://github.com/DietrichGebert/ponytail)** - plugin entre ferramentas que aplica uma escada YAGNI antes de escrever qualquer código
- **[Repomix](https://github.com/yamadashy/repomix)** - empacota o codebase num arquivo só; conectado apenas à skill manual `refresh-snapshot`, não ao contexto panorâmico (isso é o repo map nativo)
- **[OpenSpec](https://github.com/Fission-AI/OpenSpec)** - toolkit completo de desenvolvimento guiado por spec com o comando `/opsx:explore`, entre ferramentas (mais de 30 agents). Compatível com a localização `specs/` do template via config
- **[Superpowers](https://github.com/obra/superpowers)** - plugin exclusivo do Claude com fluxo reforçado de brainstorm, spec, plan, TDD

---

## Capítulo 12: Erros comuns

### 1. O CLAUDE.md se torna uma wiki

O sintoma: `CLAUDE.md` passa de 200 linhas com seções sobre toda biblioteca e convenção. O custo: toda sessão paga por tudo isso, e o conteúdo duplica com o `AGENTS.md`.

O conserto: faça do `CLAUDE.md` um **stub** que aponta para `AGENTS.md` para o conteúdo compartilhado (stack, comandos, convenções, estrutura), e mantenha-o magro, só com extras específicos do Claude (quais skills/agents/hooks este projeto entrega). Mova o material de referência detalhado para `baseline/docs/`, dê escopo a convenções em `baseline/rules/` com `paths:`, e coloque orientação específica de pasta em CLAUDE.md aninhado.

### 2. Skills com descrições vagas

O sintoma: uma skill existe mas o Claude nunca a auto-invoca.

O conserto: a `description` é o gatilho, não documentação. Escreva-a como uma condição: "Use when adding a new webhook handler" vence "Helps with webhook integrations".

### 3. Rules sem `paths:`

O sintoma: uma rule carrega automaticamente em toda sessão, se tornando um CLAUDE.md escondido.

O conserto: sempre adicione `paths:` para dar escopo a rules. Do contrário elas pertencem ao `CLAUDE.md` (e provavelmente deveriam ser mais curtas).

### 4. Docs de biblioteca duplicados de fontes oficiais

O sintoma: `baseline/docs/libs/<lib>.md` é uma cópia da referência oficial da API. Fica defasado rápido.

O conserto: `baseline/docs/libs/` deve conter só o subconjunto específico do projeto e as pegadinhas. Use Context7 MCP para docs oficiais em tempo real.

### 5. A spec é ignorada no meio da implementação

O sintoma: o código se desvia da spec, ninguém percebe até o QA.

O conserto: quando código e spec discordam, pare e pergunte qual está certo. O subagent `code-reviewer` roda automaticamente em cada limite de fase para pegar o desvio cedo.

### 6. A memória do subagent fica desatualizada

O sintoma: o subagent dá conselho baseado num padrão que não existe mais no codebase.

O conserto: revise o `MEMORY.md` periodicamente (a cada um ou dois meses). Depois de grandes refactors, limpe: `rm -rf .claude/agent-memory/<name>/`.

### 7. Permissões do subagent amplas demais

O sintoma: um `code-reviewer` edita arquivos por acidente em vez de só reportar.

O conserto: dê escopo estreito ao campo `tools:`. Um reviewer precisa de `Read, Grep, Glob`, não de `Edit`.

---

## O que ler a seguir

- A [documentação oficial do Claude Code](https://code.claude.com/docs/en/claude-directory)
- O [repo do Superpowers](https://github.com/obra/superpowers) para desenvolvimento guiado por spec
- A [convenção AGENTS.md](https://agents.md) para orientação entre ferramentas
- Abra o [`CLAUDE.md`](./CLAUDE.md), o [`AGENTS.md`](./AGENTS.md) e o [`.claude/`](./.claude/) deste repo e leia-os como referência
