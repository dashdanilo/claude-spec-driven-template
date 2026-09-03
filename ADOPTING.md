# Adotando este harness

Guia prático para quem não construiu isto. Se você quer o *porquê*, leia o
[`README.md`](./README.md) para a estrutura e o [`LEARN.md`](./LEARN.md) para o
raciocínio. Este arquivo é o *como*: instalar, e saber qual skill usar em cada
momento.

---

## O que você ganha

Dezenove skills, sete subagents, cinco rules e um conjunto de hooks de proteção.
Uma forma de trabalhar spec-driven que é a mesma em todo repositório onde você
ligar, e ausente nos que você não ligar.

Duas coisas chegam por caminhos diferentes, e essa separação é o desenho inteiro:

| | o quê | como chega | vai pro git? |
|---|---|---|:--:|
| **Método** | skills, agents, rules, hooks portáveis | **symlink** do seu clone deste repo | não |
| **Contexto** | `AGENTS.md`, `CLAUDE.md`, `docs/`, `specs/`, guardas do repo | **cópia** dentro do repositório | sim |

Método é como *você* trabalha: idêntico para todo mundo, opt-in por repo,
invisível para os colegas. Contexto é o que o *repositório* é: compartilhado com
o time, diferente em cada repo. As ADRs 0002 e 0003 no marketplace do njord têm
o raciocínio e os custos.

---

## Instalação

### 1. Clone este repo, uma vez, num lugar definitivo

```bash
git clone https://github.com/dashdanilo/claude-spec-driven-template ~/Sites/harness
```

**Escolha o caminho com calma e não mova depois.** Os links são absolutos: se
você mover esse diretório, todo projeto que optou passa a apontar para o nada,
em silêncio. Existe um aviso para isso (mais abaixo), mas o mais barato é não
causar.

### 2. Ligue num projeto

```bash
cd ~/Sites/algum-projeto
~/Sites/harness/install-harness.sh --dry-run   # veja antes
~/Sites/harness/install-harness.sh
```

Isso cria três symlinks e registra os hooks portáveis:

```
.claude/skills        -> ~/Sites/harness/baseline/skills
.claude/agents        -> ~/Sites/harness/baseline/agents
.claude/rules/harness -> ~/Sites/harness/baseline/rules
```

**Nada é commitado.** Os links vão para o `.git/info/exclude` (por clone, nunca
sobe) e os hooks para o `.claude/settings.local.json` (já gitignorado). Quem
clonar o repo não vê symlink pendurado, e o CI não vê nada. Ligar num repo que
você divide com outras pessoas é seguro.

Repita em cada projeto que você quiser. Repo onde você nunca rodar fica intacto.

### 3. Se o repo já tem uma cópia antiga do harness

```bash
~/Sites/harness/install-harness.sh --adopt
```

Sem `--adopt`, o instalador **para** em vez de sobrescrever qualquer coisa. Com
ele, o que está no caminho vira `.claude/<nome>.pre-harness` e o link entra por
cima. Isso inclui arquivos individuais que colidiriam, porque rules e commands
se **mesclam** em vez de serem substituídos: um repo com `delegation.md` próprio
carregaria a regra duas vezes. O `--unlink` devolve todos eles.

> Enquanto estiver adotado, o git reporta os arquivos deslocados como
> **deletados**. Eles são versionados e o symlink não os expõe. **Não commite,
> não faça merge e não dê pull nesse estado.** Ou rode `--unlink` para restaurar,
> ou apague as cópias `.pre-harness` de propósito, como um commit próprio, quando
> tiver decidido.
>
> O merge é o que morde de verdade: o git acha os arquivos deletados, então
> qualquer operação que restaure a working tree os escreve **por cima dos links**.
> Você fica com um `.claude/skills` real ao lado de um `.claude/skills.pre-harness`
> órfão, e o `--unlink` não conserta porque o destino está ocupado. A saída é
> `git checkout -- .claude`, que é autoritativo, e remover a sobra à mão.
> **Desfaça antes de mergear, re-adote depois.**

### 4. Projeto novo, ainda sem contexto

```bash
cd ~/Sites/projeto-novo
~/Sites/harness/install.sh          # AGENTS.md, CLAUDE.md, docs/, specs/, guardas
~/Sites/harness/install-harness.sh  # o método
```

Depois, personalize o `AGENTS.md`. É de lá que o `verify-before-done` descobre os
comandos de install, build e teste, então o gate não funciona enquanto ele não
estiver preenchido.

### Windows

Se você estiver no **Git Bash nativo**, o `ln -s` não cria symlink sem **Modo de
Desenvolvedor** ligado (ou terminal como admin). O instalador detecta isso: ele
tenta o link, confere se de fato virou link e, se não virou, **copia e avisa**.

```
COPIED     .claude/skills (this platform would not make a symlink)
```

Uma cópia funciona igual no dia a dia, mas **não acompanha o checkout**. Então
para você, `git pull` sozinho não atualiza nada: **rode o instalador de novo
depois de puxar.** O `--status` diz quais entradas são cópia. E o `check-baseline.sh` compara a sua cópia com o harness na abertura da sessão: se ela ficou para trás, ele avisa e manda rodar o instalador de novo. Você não precisa lembrar sozinho.

Ligar o Modo de Desenvolvedor no Windows, ou usar WSL, devolve o comportamento
de symlink e o `git pull` volta a bastar.

### Atualizar

```bash
git -C ~/Sites/harness pull
```

Esse é o mecanismo de atualização inteiro — **desde que os seus sejam symlinks**. Se o `--status` disser `COPIED`, rode o instalador de novo depois do pull. Todo projeto que você linkou recebe na
hora, porque todos leem os mesmos arquivos.

### Remover

```bash
cd ~/Sites/algum-projeto
~/Sites/harness/install-harness.sh --unlink
```

Restaura o que o `--adopt` tiver posto de lado e limpa o que criou. O `--status`
mostra o que está linkado no repo atual.

---

## Qual skill, quando

Digite `/nome` para invocar. O Claude também as escolhe sozinho quando a tarefa
casa: as descrições são o gatilho.

### Antes de escrever código

| skill | use quando |
|---|---|
| **`explore`** | a ideia está vaga e você ainda não sabe a solução certa. Discute tradeoffs e não escreve nada em disco |
| **`grilling`** | você precisa **fechar** decisões em aberto. Uma pergunta por vez, percorrendo a árvore de decisão, com recomendação em cada uma |
| **`devils-advocate`** | uma spec ou plano parece pronto. Pre-mortem, red-team, falsificar as premissas antes de gastar a semana |
| **`find-existing-first`** | você está prestes a criar arquivo, componente ou util novo. Procura o que já existe antes |
| **`codebase-explorer`** *(agent)* | precisa entender uma área desconhecida antes de dimensionar. Somente leitura |

### Virando trabalho

| skill | use quando |
|---|---|
| **`write-spec`** | a ideia está formada. Cria `specs/YYYY-MM-DD-<slug>/` com o `spec.md` preenchido e `plan.md`/`tasks.md` esqueletados, e passa o `spec-reviewer` automaticamente |
| **`spec-worktree`** | você vai sair do planejamento e começar a construir. Um worktree por feature, para trabalho paralelo não brigar por branch |

### Fazendo o trabalho

| skill | use quando |
|---|---|
| **`wave`** | **na maior parte das vezes.** Um lote de clusters coesos (5-7 tasks cada, um specialist por cluster), despachados em paralelo, um gate, e para. Sem spec, sem tabela de aprovação, sem PR |
| **`orchestrate`** | uma spec inteira, do começo ao fim. Reconcilia os checkboxes contra o código, classifica cada task para escolher os gates, agrupa em **clusters coesos de 5-7 tasks** (um agent por task foi a pior arquitetura medida), planeja waves, pede aprovação, executa uma wave por vez e abre o PR. Mais cerimônia: use quando o trabalho merecer |
| **`verify-before-done`** | antes de dizer que algo está pronto. Roda o install, typecheck, build e testes **deste** repo, descobertos do `AGENTS.md` |
| **`diagnosing-bugs`** | bug difícil ou regressão de performance. O gate é um loop de feedback reprodutível **antes** de qualquer hipótese |

### Fechando

| skill | use quando |
|---|---|
| **`checkpoint`** | você quer um ponto de salvamento confiável. Roda o gate e commita, nunca no vermelho |
| **`documenting-domains`** | uma feature subiu e o conhecimento precisa sobreviver à spec. Escreve `CLAUDE.md` aninhados |
| **`handover`** | a sessão está longa ou você vai parar. Reconcilia o `tasks.md` contra a realidade, descreve o que **é verdade** (nunca o que fazer em seguida), imprime um bloco copiável e manda limpar |
| **`status`** | "onde eu estou?" Cartão de saúde somente-leitura: spec ativa, tasks abertas, gates, branch, snapshot |

### Sobre o próprio harness

| skill | use quando |
|---|---|
| **`analyze-codebase`** | uma vez, ao adotar num projeto existente. Detecta stack e convenções, gera a documentação inicial |
| **`refresh-snapshot`** | o snapshot do Repomix está velho e você quer atualizar agora |
| **`harness-report`** | "estou usando isto do jeito que foi desenhado?" Reporta quanto da implementação é de fato delegada, comparado com números medidos |
| **`skill-architect`** | você vai escrever uma skill ou agent novo e quer que siga o padrão da casa |
| **`skill-best-practices`** | padrões de autoria: frontmatter, disclosure progressivo, descrições |

---

## Os subagents

Rodam em janela de contexto própria, então um trabalho grande não polui a sua.
A maioria é despachada pelas skills acima; você também pode pedir pelo nome.

| agent | faz |
|---|---|
| `codebase-explorer` | arqueologia somente-leitura. Responde "onde mora X", dimensiona uma mudança |
| `spec-reviewer` | audita o `spec.md` antes de virar plano. O `write-spec` chama sozinho |
| `code-reviewer` | revisa a implementação contra a spec, o plano e as tasks ativas |
| `reviewer` | revisão de branch inteira em nível sênior, roda a verificação do repo e pode abrir o PR |
| `tester` | escreve e roda testes usando o framework **deste** repo, descoberto do tooling |
| `researcher` | mergulha numa lib ou API externa. Mantém memória entre sessões |
| `security-auditor` | auth, segredos, validação de input. Barato e afiado, vale rodar antes de release |

---

## Rules e hooks

**Rules** carregam sozinhas conforme um glob `paths:`, então não custam nada até
serem relevantes. Quatro vêm no harness, mais um exemplo:

- `delegation.md`: sempre ligada. A thread principal coordena, os specialists implementam
- `git-workflow.md`: sempre ligada. Nome de branch, Conventional Commits, convenção de PR
- `specs.md`: em `specs/**`. Afirmações são verificadas contra código e git, nunca copiadas de prosa antiga
- `adr.md`: em `docs/decisions/**`. ADR é append-only, se supersede em vez de reescrever

**Rule do projeto ganha da rule do harness** com o mesmo nome, então um repo
sempre pode sobrescrever. (Com skills é o contrário, vale lembrar.)

**Hooks** são proteções que rodam independente do que o Claude decidir. Os
portáveis são registrados pelo `install-harness.sh`: `block-secrets.sh`,
`protect-main.sh`, `log-agent.sh`, `log-edit.sh`.

Dois **não** entram junto com o método de propósito, porque são guardas que o
repositório deve a todos, inclusive a quem nunca instalou isto. O `install.sh` os
copia para dentro do repo: `protect-critical.sh` e `check-snapshot-on-session.sh`.

---

## Quando algo der errado

**O `/orchestrate` sumiu, as skills não existem.** Os links quebraram, quase
sempre porque o clone do harness foi movido ou apagado. **O Claude Code não dá
erro nisso**: as skills simplesmente não estão lá e a sessão parece normal. O
`check-baseline.sh` avisa no início da sessão. Resolve rodando o instalador de novo.

```bash
~/Sites/harness/install-harness.sh --status   # o que está linkado aqui
```

**Worktree novo sem harness.** Não deveria acontecer: o `spec-worktree.sh` leva
os links junto. Se você criou o worktree na mão com `git worktree add`, rode o
instalador dentro dele.

**O instalador se recusa a rodar.** Tem algo real no caminho. Rode com `--adopt`
para pôr de lado, ou mova você mesmo. Ele não apaga seus arquivos.

**Uma regra parece carregar duas vezes.** O repo tem cópia própria de uma rule do
harness. É exatamente isso que o `--adopt` resolve. Se você linkou sem ele,
remova a duplicata de `.claude/rules/`.

**O gate não sabe o que rodar.** O `verify-before-done` lê os comandos do
`AGENTS.md`. Preencha.

---

## O que isto **não** faz

- **Não é imponível.** Quem não instalar não tem, e o CI nunca tem. O que precisa
  valer para todos pertence ao repositório, não aqui.
- **Não tem pinning de versão.** Todo projeto que você linkou segue a working
  tree do seu clone, então um edit não commitado lá fica vivo em todos de uma
  vez. O `check-baseline.sh` reporta isso, mas não impede.
- **Os links são da sua máquina.** Nunca são commitados, então não prejudicam
  ninguém, mas são seus e quebram se você mover o clone.
