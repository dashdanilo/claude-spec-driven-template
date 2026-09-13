# Adotando este harness

Guia prático para quem não construiu isto. Se você quer o *porquê*, leia o
[`README.md`](./README.md) para a estrutura e o [`LEARN.md`](./LEARN.md) para o
raciocínio. Este arquivo é o *como*: instalar, e saber qual skill usar em cada
momento.

---

## O que você ganha

Vinte skills, oito subagents, cinco rules e um conjunto de hooks de proteção.
Uma forma de trabalhar spec-driven que é a mesma em todo repositório onde você
ligar, e ausente nos que você não ligar.

Duas coisas chegam por caminhos diferentes, e essa separação é o desenho inteiro:

| | o quê | como chega | vai pro git? |
|---|---|---|:--:|
| **Método** | skills, agents, rules, docs, scripts, hooks portáveis | **symlink** do seu clone deste repo | não |
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

Isso cria cinco symlinks e registra os hooks portáveis:

```
.claude/skills          -> ~/Sites/harness/baseline/skills
.claude/agents          -> ~/Sites/harness/baseline/agents
.claude/rules/harness   -> ~/Sites/harness/baseline/rules
.claude/docs/harness    -> ~/Sites/harness/baseline/docs
.claude/scripts/harness -> ~/Sites/harness/baseline/scripts
```

Os dois últimos ficam num subdiretório pelo mesmo motivo que `rules/harness`: não
substituem a pasta inteira, então `.claude/docs/libs/` (como este projeto usa
cada lib) e um `.claude/scripts/` próprio do repositório convivem com o que o
harness linkou.

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

O `--adopt` resolve o **método**: as pastas de skills, agents e rules que
colidem. Ele não sabe nada sobre um plugin de stack, nunca toca o
`settings.json` commitado do repo, e não toca sozinho cópias antigas soltas em
`.claude/docs`, `.claude/scripts` ou `.claude/hooks`: essas convivem em paz ao
lado das subpastas `harness/` que o link cria, então o `--adopt` não tem
motivo pra mexer nelas. Se a cópia antiga também tinha specialists de stack
(agents e skills que vieram de um plugin, não deste harness), migre nesta
ordem:

1. **Habilite e atualize o plugin de stack antes de adotar** (seção "Plugins de
   stack" acima). O `--adopt` põe a pasta inteira de skills vendorizadas de
   lado; as skills de stack só voltam pelo plugin, e uma cópia velha do plugin
   é pior do que nenhuma, porque parece funcionar.
2. **Abra a sessão de dentro do repo que vai migrar**, não do clone do
   harness. O `protect-harness.sh` bloqueia, por desenho, edição de
   `.claude/settings.json`, hooks e rules de **outro** repositório, e decide o
   que é "outro repo" pelo diretório em que a sessão está rodando. Uma sessão
   aberta no clone do harness não consegue fazer esta migração num projeto
   diferente, e isso é a guarda funcionando, não um bug.
3. **Classifique os arquivos versionados antes de rodar `--adopt`, contra as
   duas fontes possíveis.** Conteúdo em `.claude/skills`, `.claude/agents`,
   `.claude/rules`, `.claude/docs`, `.claude/scripts` ou `.claude/hooks` deste
   repo não é necessariamente vendorizado do harness: parte pode ter vindo do
   plugin de stack, e o `--adopt` só sabe procurar na primeira fonte. Compare
   o hash de cada arquivo rastreado contra o histórico do clone do harness E
   contra o clone do marketplace que o próprio Claude Code mantém em
   `~/.claude/plugins/marketplaces/<marketplace>` (existe em qualquer máquina
   que já instalou o plugin; troque `<marketplace>` pelo nome usado, `njord`
   no exemplo):

   ```bash
   HARNESS=$(git -C ~/Sites/harness rev-list --all --objects | awk '{print $1}')
   MKT=$(git -C ~/.claude/plugins/marketplaces/njord rev-list --all --objects | awk '{print $1}')
   git ls-files .claude/skills .claude/agents .claude/rules .claude/docs .claude/scripts .claude/hooks | while read -r f; do
     h=$(git hash-object "$f")
     if printf '%s\n' "$HARNESS" | grep -qxF "$h"; then echo "harness  $f"
     elif printf '%s\n' "$MKT" | grep -qxF "$h"; then echo "plugin   $f"
     else echo "LOCAL    $f"; fi
   done
   ```

   Três baldes:
   - `harness` e `plugin`: o conteúdo já existiu, idêntico ou em versão
     antiga, na fonte que o nome diz. Sai do repo (passo 7).
   - `LOCAL`: não apareceu em nenhuma das duas fontes. **Não quer dizer
     "manter"**, quer dizer "leia antes de decidir" (passo 5).

   Como referência do que esperar, rodado no njord-back em 2026-09-13: 43
   arquivos caíram em `harness`, 88 em `plugin`, 10 em `LOCAL`. Só esse último
   grupo pede leitura arquivo por arquivo; os outros dois já estão decididos.
4. Rode `--adopt` primeiro em modo de leitura, depois de verdade:
   ```bash
   ~/Sites/harness/install-harness.sh --adopt --dry-run
   ~/Sites/harness/install-harness.sh --adopt
   ```
5. **Decida o que caiu no balde `LOCAL` do passo 3.** No njord-back os 10
   misturavam três coisas: o que é do repo por natureza (uma rule de stack,
   uma guarda que o próprio time escreveu), um ajuste local antigo que o
   harness já absorveu de outro jeito, e edição real que vale subir para o
   harness ou para o plugin. Só a leitura de cada um separa os três; qual
   decisão cabe a cada arquivo é trabalho da sessão que está migrando, não
   deste guia.

   Duas regras para quem for manter uma guarda:

   - **Guarda vendorizada pode imprimir "BLOCKED" sem bloquear.** Confira que
     o caminho de bloqueio dela termina em `exit 2`; no Claude Code, `exit 2`
     bloqueia a chamada e `exit 1` só mostra a mensagem e deixa a ação
     acontecer. Não precisa ler o script inteiro: rode o hook com um payload
     que deveria ser bloqueado e olhe o código de saída, comparando com a
     mesma guarda em `baseline/hooks/` num repo descartável, por exemplo:
     ```bash
     printf '%s' '{"tool_input": {"file_path": "yarn.lock"}}' | bash baseline/hooks/protect-critical.sh; echo $?
     ```
     Escolha um payload assim, que não dispare as guardas **vivas** da sua
     própria sessão: um exemplo que cite `.env` ou monte um commit de
     verdade aciona o `block-secrets.sh` ou o `protect-main.sh` da sua sessão
     atual antes mesmo de chegar no hook que você queria testar.
   - **Ao atualizar uma guarda do repo a partir do `baseline/hooks/`, leve
     junto os padrões que só o repo tinha.** Uma guarda de arquivos críticos
     pode proteger caminhos que o baseline não conhece (uma pasta de
     migrations do ORM do repo, um arquivo de schema gerado). Copiar o
     baseline por cima apaga essa proteção em silêncio, e é exatamente o tipo
     de arquivo que a classificação do passo 3 já marcou como `LOCAL`.
6. **Edite o `settings.json` commitado do repo:** remova as entradas dos
   hooks portáveis que **estiverem** registradas ali, nem todo repo registrou
   os mesmos. Os candidatos, conferidos no `install-harness.sh` deste
   harness, são seis: `block-secrets.sh`, `protect-main.sh` e `log-edit.sh`
   (em `Bash`/`Edit|Write|MultiEdit|NotebookEdit`), `log-agent.sh`
   (`SubagentStop`), e `check-index.sh` e `check-baseline.sh`
   (`SessionStart`); no njord-back, por exemplo, `log-edit.sh` e
   `check-baseline.sh` nunca estiveram commitados ali, não tem entrada para
   tirar. Remova também os hooks que o plugin de stack já registra sozinho
   (seção "Plugins de stack"), mantenha as guardas que são do repositório, e
   registre o `protect-harness.sh` no grupo `Edit|Write|MultiEdit|
   NotebookEdit`: esse fica nos dois lugares de propósito, não é removido.
   Tirar a entrada sem apagar o arquivo do hook deixa uma cópia velha no
   repo: o arquivo sai junto, pelo balde do passo 3 (`harness` ou `plugin`).
7. **Suba as remoções com `git rm --cached <caminho>`, nunca com
   `git add -A`.** Para cada arquivo dos baldes `harness` e `plugin` (passo
   3), rode `git rm --cached` no caminho original: o `--adopt` já tirou o
   arquivo do working tree, então isso só confirma a remoção no índice.
   Cuidado com um caso: se um arquivo do balde `harness` for uma das guardas
   que o `install.sh` copia de propósito para dentro do repo
   (`protect-critical.sh`, `check-snapshot-on-session.sh`,
   `protect-harness.sh`) e ela ainda está registrada no `settings.json` como
   guarda deste repositório, não é lixo vendorizado, é a cópia que deve
   ficar; confirme pelo `settings.json`, o balde sozinho não basta para esses
   três. Testado num repo descartável: `git add -A` sobe o symlink em si como
   um arquivo normal (modo `120000`, o alvo do link como conteúdo, sem seguir
   para dentro dele) e sobe qualquer pasta `.claude/<nome>.pre-harness`
   inteira como arquivos novos, o oposto do que se quer. As pastas
   `.pre-harness` nunca chegaram a ser rastreadas com esse nome; apague-as do
   disco à parte, fora do git, depois de commitar. Confira o `git status`
   inteiro antes de commitar.
8. **Corrija a documentação do repo que aponta para caminhos que agora vêm do
   harness ou do plugin** (por exemplo, um script que estava em
   `.claude/scripts/spec-worktree.sh` passa a ser
   `.claude/scripts/harness/spec-worktree.sh`; uma skill que passou a vir do
   plugin de stack não tem mais caminho dentro do repo).
9. **Verifique:**
   ```bash
   ~/Sites/harness/install-harness.sh --status
   bash .claude/scripts/harness/check-index.sh --strict
   ```
   e a suíte de testes do próprio repo.
10. **Um PR só com as remoções.** As pastas `.pre-harness` só podem sumir de
    verdade depois do merge desse PR. Enquanto a migração estiver feita mas
    não commitada, vale o mesmo aviso do bloco acima: não commite, não faça
    merge, não dê pull nesse estado.

### 4. Projeto novo, ainda sem contexto

```bash
cd ~/Sites/projeto-novo
~/Sites/harness/install.sh          # AGENTS.md, CLAUDE.md, docs/, specs/, guardas
~/Sites/harness/install-harness.sh  # o método
```

Depois, personalize o `AGENTS.md`. É de lá que o `verify-before-done` descobre os
comandos de install, build e teste, então o gate não funciona enquanto ele não
estiver preenchido.

Se o seu time já tem (ou vai escrever) um `script/setup` e um `script/test`
executáveis na raiz do repo, o harness passa a **chamá-los** em vez de
redescobrir comandos: o `spec-worktree` roda o `script/setup` ao criar um
worktree, e o `verify-before-done` usa o `script/test` como o próprio gate. O
harness não gera esses scripts — só o time sabe o que "pronto" e "verificado"
significam ali — e um repo sem eles não perde nada, o passo vira no-op. Ver
[`docs/guides/script-setup-and-test.md`](./docs/guides/script-setup-and-test.md).

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

## Plugins de stack

O harness sozinho não traz nenhum specialist de stack. Os agents como `backend`,
`database` ou `graphql`, e as skills como `prisma-*`, `graphql-codefirst`,
`nestjs-module`, `testing`, `backend-*` ou `file-uploads`, vêm de um **plugin**,
não deste repositório. No njord-back é o `backend-nest@njord`, habilitado em
`enabledPlugins` no `.claude/settings.json` **commitado** do repo (não no seu
`settings.local.json`). Com o plugin ativo, o Agent tool mostra esses
specialists com o namespace do plugin na frente, por exemplo
`backend-nest:backend`.

Sem o plugin habilitado, a regra de delegação não trava: ela cai para o
`implementer` deste harness, o fallback portátil. Ele funciona (lê o
`AGENTS.md`, as rules do repo, o código ao lado da mudança) mas não conhece a
stack, e diz isso no próprio relatório. Se você esperava ver
`backend-nest:backend` num despacho e apareceu `implementer`, o plugin não está
habilitado.

**Plugin não carrega rules.** O manifest de um plugin não tem campo para isso;
o marketplace do njord removeu a pasta `rules/` de dentro do plugin porque ela
nunca era lida (commit `6d47157`). Por isso as rules de stack (no njord-back,
`nestjs-module.md`, `prisma-database.md`, `code-quality.md`) moram no
`.claude/rules/` do próprio repositório, não no plugin. A ADR 0002 do
marketplace do njord registra essa divisão.

**Plugin registra os próprios hooks**, pelo `hooks/hooks.json` de dentro dele.
O `backend-nest`, por exemplo, registra um `protect-prisma.sh` igual ao que o
njord-back já tem em `.claude/hooks/`. Se o repo continuar registrando a cópia
dele no `settings.json` depois de habilitar o plugin, a guarda roda duas vezes
por chamada. Ao migrar um repo que já tinha essa cópia (próxima seção), pare de
registrar a cópia do repo e deixe o plugin cuidar disso.

**A cópia instalada do plugin pode estar velha, e nada avisa sozinho.** O
Claude Code guarda o plugin em cache por versão, em
`~/.claude/plugins/cache/<marketplace>/<plugin>/<versão>/`, e identifica a
instalação pelo campo `version`, não pelo commit. Um plugin do marketplace
njord pode ter recebido commits de conteúdo sem nunca subir de versão (o
`backend-nest` recebeu três e continua em `0.1.0`), e nesse caso a sua cópia
instalada não muda mesmo depois do marketplace mudar.

Para atualizar:

```bash
claude plugin update backend-nest@njord
```

Reinicie a sessão depois: o próprio comando avisa que a atualização só é
aplicada num processo novo.

Verificado em 2026-09-13: rodando `claude plugin update backend-nest@njord
--json`, a resposta foi `"updateOutcome":"up_to_date"`, com a mensagem
"backend-nest is already at the latest version (0.1.0)", isso mesmo com o
clone de marketplace do Claude Code já num commit mais novo (11/09) do que a
instalação (14/07). O `gitCommitSha` do plugin em `installed_plugins.json` e a
pasta de cache continuaram exatamente como antes do `update`. O comando
compara **versão**, não commit: sem o marketplace subir a versão do plugin, o
`update` não traz conteúdo novo, mesmo com o marketplace à frente. Quando a
versão subir, o mesmo comando traz.

Continue conferindo o `gitCommitSha` antes e depois do `update`: é assim que
você sabe se ele de fato trouxe algo novo. O default do comando é
`--scope user`; se o plugin foi instalado por projeto, use `--scope project`
para atualizar a instalação certa.

```bash
claude plugin details backend-nest@njord
```

mostra o inventário de componentes que a cópia instalada de fato tem (skills,
agents, hooks), útil para conferir se bate com o que você espera antes de
confiar nela.

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
| **`jury`** | precisa **decidir entre opções concorrentes** (arquitetura, vendor, caminho de migração) e errar sai caro. Um painel de 3 a 5 subagents argumenta às cegas, depois em duas rodadas, e termina num veredito com o dissenso preservado |
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
| **`verify-before-done`** | antes de dizer que algo está pronto. Se o repo tem um `script/test` executável na raiz, roda ele; senão descobre install, typecheck, build e testes do `AGENTS.md` **deste** repo |
| **`diagnosing-bugs`** | bug difícil ou regressão de performance. O gate é um loop de feedback reprodutível **antes** de qualquer hipótese |

### Fechando

| skill | use quando |
|---|---|
| **`checkpoint`** | você quer um ponto de salvamento confiável. Roda o gate e commita, nunca no vermelho |
| **`documenting-domains`** | uma feature subiu e o conhecimento precisa sobreviver à spec. Escreve `CLAUDE.md` aninhados |
| **`handover`** | a sessão está longa ou você vai parar. Reconcilia o `tasks.md` contra a realidade, descreve o que **é verdade** (nunca o que fazer em seguida), **sempre grava um arquivo** (na spec ativa, ou em `.claude/handovers/` quando não há spec), imprime um bloco copiável e manda limpar |
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
| `implementer` | implementador portátil de fallback: usado só quando não existe specialist de stack para o trabalho. Lê o `AGENTS.md`, as rules e o código ao lado da mudança antes de escrever, e nomeia no relatório qual specialist deveria existir |
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
`protect-main.sh`, `protect-harness.sh`, `log-agent.sh`, `log-edit.sh`.

Três **não** entram junto com o método de propósito, porque são guardas que o
repositório deve a todos, inclusive a quem nunca instalou isto. O `install.sh`
os copia para dentro do repo: `protect-critical.sh`, `check-snapshot-on-session.sh`
e `protect-harness.sh`. Os dois primeiros ficam só na cópia — dizem respeito ao
repositório (lockfile, migration, snapshot), não a uma máquina. `protect-harness.sh`
é o caso oposto e por isso entra nos dois lugares: é a própria governança do
harness, e a regra dela é o critério, não a lista de padrões (essa está no
`CLAUDE.md`) — um agente pode mexer no que vai aparecer num review deste repo,
nunca no de outro repo, nunca no que é gitignorado e por isso invisível.

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

**Um agente não consegue registrar hook nenhum no `settings.local.json`.**
Esse arquivo é gitignorado, e o `protect-harness.sh` bloqueia governança que
não aparece em nenhum review por desenho. Quem registra os hooks portáveis ali
é o `install-harness.sh`, rodado por você, uma pessoa, no terminal.

---

## O que isto **não** faz

- **Não é imponível.** Quem não instalar não tem, e o CI nunca tem. O que precisa
  valer para todos pertence ao repositório, não aqui.
- **Não tem pinning de versão.** Todo projeto que você linkou segue a working
  tree do seu clone, então um edit não commitado lá fica vivo em todos de uma
  vez. O `check-baseline.sh` reporta isso, mas não impede.
- **Os links são da sua máquina.** Nunca são commitados, então não prejudicam
  ninguém, mas são seus e quebram se você mover o clone.
