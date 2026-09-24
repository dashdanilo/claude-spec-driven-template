# Adotando este harness

Guia prático para quem não construiu isto. Se você quer o *porquê*, leia o
[`README.md`](./README.md) para a estrutura e o [`LEARN.md`](./LEARN.md) para o
raciocínio. Este arquivo é o *como*: instalar, e saber qual skill usar em cada
momento.

---

## O que você ganha

Vinte e três skills, oito subagents, seis rules e um conjunto de hooks de proteção.
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
export HARNESS=~/Sites/harness   # escolha o caminho com calma, ver aviso abaixo
git clone https://github.com/dashdanilo/claude-spec-driven-template "$HARNESS"
```

O resto deste guia usa `$HARNESS` em todo bloco. Se você abrir uma sessão nova,
exporte a variável de novo antes de colar qualquer comando daqui.

**Escolha o caminho com calma e não mova depois.** Os links são absolutos: se
você mover esse diretório, todo projeto que optou passa a apontar para o nada,
em silêncio. Existe um aviso para isso (mais abaixo), mas o mais barato é não
causar.

### 2. Ligue num projeto

```bash
cd ~/Sites/algum-projeto
"$HARNESS/install-harness.sh" --dry-run   # veja antes
"$HARNESS/install-harness.sh"
```

Isso cria os symlinks e registra os hooks portáveis:

```
.claude/skills/<nome>     -> $HARNESS/baseline/skills/<nome>      um por skill
.claude/agents/<nome>.md  -> $HARNESS/baseline/agents/<nome>.md   um por agent
.claude/rules/harness     -> $HARNESS/baseline/rules
.claude/docs/harness      -> $HARNESS/baseline/docs
.claude/scripts/harness   -> $HARNESS/baseline/scripts
```

**Skills e agents são linkados um a um**, nunca a pasta inteira. O Claude Code
só procura skill e agent direto em `.claude/skills/` e `.claude/agents/`, então
a saída das outras três (uma subpasta `harness/`) não serve para eles; e um link
da pasta inteira esconderia toda skill ou agent que o próprio repositório versiona
ali. Um a um, as do repo e as do harness convivem na mesma pasta. O instalador só
para se o repo tiver um item **com o mesmo nome** de um que o harness entrega
(ver seção 3).

Rules, docs e scripts ficam num subdiretório pelo mesmo motivo: não substituem a
pasta inteira, então `.claude/rules/` do repo, `.claude/docs/libs/` (como este
projeto usa cada lib) e um `.claude/scripts/` próprio convivem com o que o
harness linkou.

O custo de linkar um a um: o `git pull` atualiza o conteúdo de tudo que já está
linkado, mas uma skill ou agent que o harness **criar ou renomear** depois só
aparece rodando o instalador de novo. O `check-baseline.sh` avisa disso no início
da sessão, com o nome do item que falta.

**Nada é commitado.** Os links vão para o `.git/info/exclude` (nunca sobe) e os
hooks para o `.claude/settings.local.json` (já gitignorado). Quem clonar o repo
não vê symlink pendurado, e o CI não vê nada. Ligar num repo que você divide com
outras pessoas é seguro. O mesmo bloco também lista os arquivos de runtime que
os próprios hooks escrevem depois de registrados (`.claude/agent-log.txt`,
`.claude/tool-log.txt`, `.claude/.agent-log-consumed`), para que a primeira
chamada de ferramenta depois do link não vire um arquivo não rastreado no
`git status`.

`.git/info/exclude` não é por clone: mora no diretório git **comum**, então numa
worktree é o arquivo do checkout principal, compartilhado por todas as
worktrees dela. Inofensivo mesmo assim: gitignore não esconde o que já está
rastreado, então se outra worktree tiver esse mesmo caminho como conteúdo de
verdade (versionado, não o link do harness), o `git status` dela continua
enxergando normalmente.

Repita em cada projeto que você quiser. Repo onde você nunca rodar fica intacto.

### 3. Se o repo já tem uma cópia antiga do harness

```bash
"$HARNESS/install-harness.sh" --adopt
```

Sem `--adopt`, o instalador **para** em vez de sobrescrever qualquer coisa. Com
ele, o que está no caminho é posto de lado e o link entra por cima:

- uma skill ou agent do repo **com o mesmo nome** de um do harness vai para
  `.claude/skills.pre-harness/<nome>` (ou `agents.pre-harness/`). Só esse item: o
  resto do que o repo tem em `.claude/skills/` fica onde está e continua
  carregando;
- rules e commands que colidiriam viram `<arquivo>.pre-harness` ao lado, porque
  se **mesclam** em vez de serem substituídos: um repo com `delegation.md`
  próprio carregaria a regra duas vezes;
- rules, docs e scripts têm a subpasta `harness/` e não colidem com nada.

O `--unlink` devolve todos eles.

> Enquanto estiver adotado, o git reporta os arquivos deslocados como
> **deletados**. Eles são versionados e o symlink não os expõe. Isso é esperado
> e commitar essa deleção é o fluxo pretendido: o passo 7 sobe exatamente essa
> remoção com `git rm`/`git rm --cached`, nunca `git add -A`, e as cópias
> `.pre-harness` ficam no disco até aquele PR mergear (passo 10). **Não faça
> merge nem dê pull nesse estado.** Mudou de ideia antes de chegar ao passo 7?
> Rode `--unlink` para restaurar tudo, em vez de commitar.
>
> O merge é o que morde de verdade: o git acha os arquivos deletados, então
> qualquer operação que restaure a working tree os escreve **por cima dos links**.
> Você fica com uma skill real ao lado da mesma skill em `.claude/skills.pre-harness`
> órfã, e o `--unlink` não conserta porque o destino está ocupado. A saída é
> `git checkout -- .claude`, que é autoritativo, e remover a sobra à mão.
> **Desfaça antes de mergear, re-adote depois.**

O `--adopt` resolve o **método**: as skills, agents, rules e commands que
colidem. Ele não sabe nada sobre um plugin de stack, nunca toca o
`settings.json` commitado do repo, e não toca sozinho cópias antigas soltas em
`.claude/docs`, `.claude/scripts` ou `.claude/hooks`: essas convivem em paz ao
lado das subpastas `harness/` que o link cria, então o `--adopt` não tem
motivo pra mexer nelas. Se a cópia antiga também tinha specialists de stack
(agents e skills que vieram de um plugin, não deste harness), migre nesta
ordem:

0. **Comece na branch certa.** O `origin/HEAD` do seu clone local pode estar
   desatualizado, ainda apontando para `main` enquanto o padrão real no GitHub
   já é outro (`develop`, por exemplo), e criar a branch de migração a partir
   dele parte do branch errado sem avisar nada. Alinhe antes de criar
   qualquer branch:
   ```bash
   git remote set-head origin --auto   # relê o HEAD default do remoto
   git checkout -b <tipo>/<slug> origin/<branch-de-integracao>
   git merge-base --is-ancestor origin/<branch-de-integracao> HEAD && echo ok
   ```
   O terceiro comando confirma que a branch nova de fato descende da branch de
   integração remota antes de seguir para o passo 1.
1. **Habilite e atualize o plugin de stack antes de adotar** (seção "Plugins de
   stack", abaixo). A cópia vendorizada de uma skill de stack sai do repo no
   passo 7; ela só volta pelo plugin, e uma cópia velha do plugin
   é pior do que nenhuma, porque parece funcionar.

   Às vezes o `update` não traz nada mesmo com o marketplace à frente, porque
   o comando compara **versão**, não commit (ver a seção abaixo). Não dá para
   esperar por isso. Siga a migração mesmo assim: um arquivo que o plugin já
   tem no marketplace mas a cópia instalada ainda não entrega cai no balde
   `fica` do passo 3, não `LOCAL`, porque nenhuma fonte o entrega hoje. Liste
   o que ficou assim, indisponível localmente até o plugin realmente
   atualizar de versão, e não invente o conteúdo que falta.
2. **Abrir a sessão de dentro do repo que vai migrar continua sendo a forma
   mais simples**, mas deixou de ser exigido pela guarda. O `protect-harness.sh`
   só bloqueia edição cross-repo quando o alvo é o PRÓPRIO checkout do harness
   (uma raiz com `install-harness.sh` e `baseline/`, dessa máquina ou de
   qualquer outra) ou um caminho gitignorado no repo alvo (ex.:
   `.claude/settings.local.json`, que nunca é editado por Edit/Write de
   qualquer forma, só pelo `install-harness.sh`). Editar `.claude/settings.json`
   já rastreado, um hook ou uma rule de um projeto comum a partir de uma sessão
   aberta no clone do harness passa: essa edição aparece no diff e no PR
   daquele repo, igual a uma edição feita de dentro dele. Risco residual aceito
   conscientemente: a mudança pode ficar sem commit no working tree do repo
   alvo por um tempo, ativa em qualquer sessão aberta ali antes de alguém
   revisar o diff (review adiado, não ausente). Ainda assim, abrir a sessão
   dentro do repo evita o resto da fricção de caminho absoluto (comandos
   relativos, o `AGENTS.md` certo carregado), então continua sendo a
   recomendação padrão.
3. **Classifique os arquivos versionados antes de rodar `--adopt`, com duas
   perguntas independentes.** Conteúdo em `.claude/skills`, `.claude/agents`,
   `.claude/rules`, `.claude/docs`, `.claude/scripts`, `.claude/hooks` ou
   `.claude/commands` deste repo não é necessariamente vendorizado do harness: parte pode ter vindo do
   plugin de stack, e parte pode ser edição do próprio repo num caminho que
   uma fonte também usa. O `--adopt` só sabe procurar na primeira hipótese.

   **Pergunta 1: a fonte entrega esse caminho hoje?** Por caminho, contra a
   árvore atual de cada fonte, não contra o histórico, e não só "existe um
   arquivo de mesmo nome na fonte": tem que ser o mecanismo que realmente
   entrega aquele caminho. Skills, agents, docs e scripts do harness chegam
   pela árvore atual do clone (`$HARNESS/baseline/<categoria>/<caminho>`, o
   mesmo que o link em `.claude/<categoria>/` ou `.claude/<categoria>/
   harness/` expõe). **Rules chegam pelo harness**, pelo mesmo link
   (`.claude/rules/harness/` aponta para `baseline/rules/`), **mas nunca pelo
   plugin**: o manifest de um plugin não tem campo para rule (ver "Plugins de
   stack", abaixo), então uma rule só passa na pergunta 1 contra o harness.
   Skills e agents de stack chegam pela cópia hoje instalada do plugin
   (`~/.claude/plugins/cache/<marketplace>/<plugin>/<versão>/<categoria>/
   <caminho>`), sem precisar de registro individual: o plugin declara a pasta
   inteira.

   **Hooks são o caso especial: o harness não linka `.claude/hooks/` nenhum.**
   Um hook chega registrado por caminho absoluto no `settings.local.json`
   (portáveis) ou copiado uma vez para dentro do repo pelo `install.sh`
   (vendorizados), nunca por uma pasta que se atualiza sozinha. Testar só "o
   harness tem um `baseline/hooks/<nome>` de mesmo nome" erra: `protect-
   critical.sh` e `check-snapshot-on-session.sh` existem em `baseline/hooks/`
   mas **não** são portáveis, são as guardas que o `install.sh` copia de
   propósito para dentro do repo (`REPO_HOOKS`, dentro do próprio
   `install.sh`), o par que quase saiu em silêncio no #885. Por isso a
   pergunta 1, para hooks, é contra três conjuntos nomeados, lidos direto dos
   instaladores, não contra um diretório:
   - nome está em `REPO_HOOKS` (`install.sh`) ou `REPO_SCRIPTS` (mesmo
     arquivo, para `.claude/scripts`): é do repo por definição, entra direto
     no balde `fica`, **independente do conteúdo**. O critério aqui não é
     proveniência, é "isto é o repo por desenho".
   - senão, nome está no dict `WANT` do `install-harness.sh`: entregue pelo
     harness (portátil).
   - senão, nome está registrado no `hooks/hooks.json` do plugin instalado:
     entregue pelo plugin.
   - nenhum dos três: nenhuma fonte entrega esse hook, vai para `fica`.

   Para scripts, raciocínio parecido, mais simples: nome em `REPO_SCRIPTS` é
   `fica` por definição; senão, existir em `baseline/scripts/<caminho>` conta
   como harness; scripts nunca vêm de plugin.

   **Commands também entram, mesmo sem nenhuma fonte entregar
   `.claude/commands/`.** O harness autora os drivers (`orchestrate`, `wave`,
   `handover`, `checkpoint`, `status`) como skills, e o `--adopt` põe de lado
   todo `commands/<nome>.md` para o qual exista `baseline/skills/<nome>/`, porque
   os dois produzem o mesmo `/nome`. Então a pergunta 1 para um command é esse
   mesmo critério de colisão: existe `baseline/skills/<nome>/`? Uma cópia antiga
   do harness costuma ter os cinco versionados; sem classificá-los, eles viram
   "deletados" no `git status` sem nunca passarem pelas duas perguntas.

   **Plugin conta só se estiver habilitado neste repo.** O que entrega é o
   plugin ligado em `enabledPlugins` no `.claude/settings.json` commitado, não
   todo plugin que por acaso esteja no cache da máquina. Um plugin desligado não
   entrega nada nesta sessão, e contar com ele autorizaria remover um arquivo
   que nenhuma fonte entrega (no website, que só liga o `frontend-next`, o cache
   inteiro trazia o `protect-prisma.sh` do `backend-nest`).

   Essa pergunta 1 sozinha só decide se o arquivo **pode** sair; não decide
   se pode sair **sem ler**.

   **Pergunta 2: o conteúdo desse arquivo veio da fonte?** Hash contra o
   arquivo atual da fonte **ou** contra qualquer versão do histórico dela
   (`git -C $HARNESS rev-list --all --objects` para o harness,
   `git -C ~/.claude/plugins/marketplaces/<marketplace> rev-list --all
   --objects` para o plugin). Um histórico inteiro aqui é o uso certo do
   hash: ele não decide sozinho **se** o arquivo sai (isso é a pergunta 1),
   só se pode sair sem alguém ler o conteúdo primeiro.

   Cruzando as duas, três baldes, não dois:
   - **`sai`**: a fonte entrega esse caminho hoje **e** o conteúdo já foi
     dessa fonte, atual ou passada. Sem edição local para perder. Remove sem
     ler (passo 7).
   - **`LOCAL`**: a fonte entrega esse caminho hoje, **mas** o conteúdo nunca
     esteve nela. É edição local por cima de um caminho que a fonte controla,
     e some em silêncio se você confiar só na pergunta 1. **Leia antes de
     decidir** (passo 5): pode ter um padrão para levar junto, uma correção
     para subir à fonte, ou ser descartável mesmo.
   - **`fica`**: nenhuma fonte entrega esse caminho hoje, **ou** é do repo por
     definição (hook/script em `REPO_HOOKS`/`REPO_SCRIPTS`, independente do
     conteúdo). Rule de stack, guarda que só o repo tem, ou algo que uma fonte
     já teve e removeu (inclusive um plugin ainda não atualizado, caso do
     passo 1). Continua no repo.

   Um quarto rótulo sai do mesmo cruzamento e não é balde próprio, é um aviso
   sobre o `fica`:
   - **`ORFAO`**: nenhuma fonte entrega esse caminho hoje, **mas** o conteúdo
     esteve numa delas. A pergunta 1 é por caminho, então um arquivo que a fonte
     **renomeou** cai aqui em vez de `sai`. No website, `skills/the-fool/SKILL.md`
     é o `devils-advocate` de antes do rename (difere em 3 linhas, então nenhum
     hash contra o caminho novo pega): tratado como `fica`, ficaria no repo para
     sempre, uma cópia congelada carregando ao lado da skill viva com outro nome.
     Descubra o que houve com o commit que tirou o caminho da fonte, que o
     próprio `rev-list` já localiza:
     ```bash
     git -C "$HARNESS" rev-list --all --objects | grep "^$(git hash-object <arquivo>)"   # caminho antigo na fonte
     git -C "$HARNESS" log --all -1 --format='%h %s' -- <caminho antigo>               # quem o tirou, e por quê
     ```
     Renomeado ou substituído: é `sai`. Plugin instalado mais velho que o
     marketplace (passo 1): é `fica`. Removido de propósito na fonte: leia e
     decida como um `LOCAL`.

   Leia os conjuntos direto dos instaladores em vez de copiá-los à mão: se um
   deles mudar, o snippet muda sozinho, e o guia não fica desatualizado em
   silêncio.

   ```bash
   MARKETPLACE=njord   # troque pelo nome usado neste projeto

   PORTABLE_HOOKS=$(grep -oE 'hooks_dir \+ "/[^"]+"' "$HARNESS/install-harness.sh" | sed -E 's#.*/([^"]+)"#\1#' | sort -u)
   eval "$(grep -oE 'REPO_HOOKS=\([^)]*\)' "$HARNESS/install.sh")"
   eval "$(grep -oE 'REPO_SCRIPTS=\([^)]*\)' "$HARNESS/install.sh")"
   # Só os plugins deste marketplace que ESTE repo liga: desligado não entrega nada.
   ENABLED_PLUGINS=$(python3 -c 'import json,sys; m=sys.argv[1]; d=json.load(open(".claude/settings.json")).get("enabledPlugins",{}); print("\n".join(k.rsplit("@",1)[0] for k,v in d.items() if v and k.endswith("@"+m)))' "$MARKETPLACE" 2>/dev/null)
   # A versão INSTALADA de verdade, não toda versão que por acaso está em cache:
   # o Claude Code guarda cada versão baixada em ~/.claude/plugins/cache/, então
   # uma 0.1.0 velha continua no disco ao lado da 0.2.0 corrente, e um `*/` ali
   # contaria a velha como "entregue hoje". `installed_plugins.json` é quem diz
   # qual instalação está de fato ativa, um registro por escopo: `project`
   # (por repositório, com `projectPath`) ou `user` (a máquina inteira).
   # Prefira o `project` deste repositório; sem um, caia para o `user`.
   plugin_dirs() {
     local p
     for p in $ENABLED_PLUGINS; do
       python3 -c '
import json, os, sys
name, mkt, cwd = sys.argv[1], sys.argv[2], sys.argv[3]
path = os.path.expanduser("~/.claude/plugins/installed_plugins.json")
try:
    entries = json.load(open(path)).get("plugins", {}).get(name + "@" + mkt, [])
except Exception:
    sys.exit(0)
chosen = next((e for e in entries if e.get("scope") == "project" and e.get("projectPath") == cwd), None)
chosen = chosen or next((e for e in entries if e.get("scope") == "user"), None)
if chosen and chosen.get("installPath"):
    print(chosen["installPath"].rstrip("/") + "/")
' "$p" "$MARKETPLACE" "$PWD"
     done
   }
   PLUGIN_HOOK_NAMES=$(plugin_dirs | while read -r d; do
     [[ -f "${d}hooks/hooks.json" ]] || continue
     grep -oE '"command":[[:space:]]*"[^"]+"' "${d}hooks/hooks.json" | sed -E 's#.*/([^"/]+)"$#\1#'
   done | sort -u)

   in_list() { local x=$1; shift; local i; for i in "$@"; do [[ "$i" == "$x" ]] && return 0; done; return 1; }
   harness_has() { [[ -e "$HARNESS/baseline/$1" ]]; }
   plugin_has_path() {
     local rel=$1 d
     while read -r d; do
       [[ -e "${d}${rel}" ]] && return 0
     done < <(plugin_dirs)
     return 1
   }

   HARNESS_HASHES=$(git -C "$HARNESS" rev-list --all --objects | awk '{print $1}')
   MKT_HASHES=$(git -C ~/.claude/plugins/marketplaces/"$MARKETPLACE" rev-list --all --objects | awk '{print $1}')
   # `&&`/`||` encadeados aqui pareciam um if-else e não eram: com $1==harness e
   # o hash ausente de HARNESS_HASHES, o `&&` inteiro dá falso e o `||` caía para
   # checar MKT_HASHES mesmo assim, então um hash só do harness podia sair "vem
   # do plugin" por acidente. if/else não tem essa armadilha.
   from_source() {
     local src="$1" h="${2:-$h}"
     if [[ "$src" == harness ]]; then
       printf '%s\n' "$HARNESS_HASHES" | grep -qxF "$h"
     else
       printf '%s\n' "$MKT_HASHES" | grep -qxF "$h"
     fi
   }
   from_any() { printf '%s\n' "$HARNESS_HASHES" "$MKT_HASHES" | grep -qxF "$1"; }
   # "igual ao harness" contra TODO o histórico (from_source harness) rotulava
   # até uma cópia velha e quebrada de protect-critical.sh como "igual", só
   # porque aquele conteúdo existiu num commit qualquer do harness no passado.
   # Primeiro compare contra o arquivo ATUAL de baseline/<cat>/<rel>: só esse
   # confere se o repo tem de verdade o que o harness entrega hoje.
   label_repo_owned() {
     local cat="$1" rel="$2" h="$3" cur="$HARNESS/baseline/$1/$2"
     if [[ -f "$cur" ]] && [[ "$(git hash-object "$cur")" == "$h" ]]; then
       echo "igual ao baseline atual"
     elif from_source harness "$h"; then
       echo "versao antiga do harness, atualize (leve os padroes proprios)"
     else
       echo "difere"
     fi
   }

   git ls-files .claude/skills .claude/agents .claude/rules .claude/docs .claude/scripts .claude/hooks .claude/commands | while read -r f; do
     cat=${f#.claude/}; cat=${cat%%/*}
     rel=${f#.claude/$cat/}
     base=$(basename "$rel")
     h=$(git hash-object "$f")
     src=""
     if [[ "$cat" == hooks ]] && in_list "$base" "${REPO_HOOKS[@]}"; then
       echo "fica     $f  ($(label_repo_owned hooks "$rel" "$h"))"; continue
     elif [[ "$cat" == scripts ]] && in_list "$base" "${REPO_SCRIPTS[@]}"; then
       echo "fica     $f  ($(label_repo_owned scripts "$rel" "$h"))"; continue
     elif [[ "$cat" == hooks ]] && printf '%s\n' "$PORTABLE_HOOKS" | grep -qxF "$base"; then
       src=harness
     elif [[ "$cat" == hooks ]] && printf '%s\n' "$PLUGIN_HOOK_NAMES" | grep -qxF "$base"; then
       src=plugin
     elif [[ "$cat" == commands ]] && [[ -d "$HARNESS/baseline/skills/${base%.md}" ]]; then
       src=harness
     elif [[ "$cat" != hooks && "$cat" != commands ]] && harness_has "$cat/$rel"; then
       src=harness
     elif [[ "$cat" == skills || "$cat" == agents ]] && plugin_has_path "$cat/$rel"; then
       src=plugin
     fi
     if [[ -z "$src" ]]; then
       from_any "$h" && echo "ORFAO    $f  (conteudo veio de uma fonte que nao entrega mais esse caminho: leia)" || echo "fica     $f"
     elif from_source "$src" "$h"; then
       echo "sai      $f"
     else
       echo "LOCAL    $f"
     fi
   done
   ```

   Rodado assim contra `origin/develop` do njord-back em 2026-09-14 (141
   arquivos rastreados nos seis diretórios): 127 em `sai`, 6 em `LOCAL`, 8 em
   `fica`.

   `LOCAL` (a fonte entrega esse caminho hoje, mas o conteúdo nunca esteve
   nela; leia antes): `hooks/block-secrets.sh`, `hooks/protect-main.sh`,
   `rules/git-workflow.md`, `scripts/spec-worktree.sh`,
   `skills/skill-architect/SKILL.md` e `skills/testing/rules/_sections.md`.
   Esse último diverge do que o #885 decidiu (a tabela "Decisão sobre os
   `LOCAL`" da descrição daquele PR tratou o par
   `{_sections,test-no-global-state-assertions}.md` como "sai" os dois): o
   plugin instalado entrega hoje um `_sections.md` nesse caminho, mas o
   conteúdo do njord-back tem uma linha a mais (a entrada da rule
   `test-no-global-state-assertions`, que o njord escreveu localmente antes
   de ela subir ao plugin) que nunca existiu em nenhum commit do marketplace;
   o #885 removeu um arquivo com edição local sem ler, exatamente o risco que
   este balde existe para pegar.

   `fica` (nenhuma fonte entrega esse caminho hoje, ou é do repo por
   definição): `rules/code-quality.md`, `rules/nestjs-module.md`,
   `rules/prisma-database.md`, `hooks/require-tests-before-push.sh`,
   `hooks/protect-critical.sh` (rotulado "difere": o njord-back ainda protege
   `prisma/migrations/` e `src/schema.gql`, que o baseline não conhece, leia
   ao atualizar), `hooks/check-snapshot-on-session.sh` e
   `scripts/check-snapshot.sh` (rotulados "igual ao baseline atual", são
   `REPO_HOOKS`/`REPO_SCRIPTS` por definição, ficam mesmo idênticos) e
   `skills/testing/rules/test-no-global-state-assertions.md`. As três rules
   de stack ficam, como manda a seção "Plugins de stack" mais abaixo: nenhum
   plugin carrega `rules/`. `test-no-global-state-assertions.md` fica pelo
   motivo do passo 1: já subiu ao marketplace em `3c3cb8e`, mas a cópia
   instalada nesta máquina é de 14/07, anterior a esse commit, e não entrega
   esse caminho ainda; quando o plugin atualizar, ele passa a ser entregue.

   `sai` inclui `hooks/log-agent.sh` e `hooks/protect-prisma.sh`: este último
   sai pelo critério (o plugin o entrega e o conteúdo é dele), mas o passo 6
   continua mandando manter as duas guardas registradas até provar, com
   payload, que a cópia do plugin bloqueia de verdade.

   Rodado contra o website em `35dabd4` (58 arquivos rastreados em `.claude/`,
   54 nos sete diretórios): 50 em `sai` (os 5 commands incluídos), 0 em
   `LOCAL`, 3 em `fica` (`protect-critical.sh`, `check-snapshot-on-session.sh`,
   `check-snapshot.sh`) e 1 `ORFAO` (`skills/the-fool/SKILL.md`, rename). Antes
   deste snippet olhar `commands/` e o cache só dos plugins ligados, o mesmo
   repo dava 45/0/4 com os commands invisíveis e o `the-fool` como `fica`.

   "Entregue hoje" sozinho **não autoriza remover**: só o balde `sai`
   autoriza, porque soma as duas perguntas. Um caminho entregue hoje com
   conteúdo que nunca esteve na fonte é `LOCAL`, e pede leitura antes de
   qualquer `git rm`.
4. Rode `--adopt` primeiro em modo de leitura, depois de verdade:
   ```bash
   "$HARNESS/install-harness.sh" --adopt --dry-run
   "$HARNESS/install-harness.sh" --adopt
   ```
5. **Decida o que caiu no balde `LOCAL` do passo 3.** No njord-back, contra
   `origin/develop`, os 6 são todos a mesma coisa: edição local por cima de um
   caminho que o harness ou o plugin entregam hoje (dois hooks portáteis
   reescritos com lógica própria, uma rule de stack que colide com o nome de
   uma rule do harness, um script e uma skill de época, e uma skill de plugin
   com uma linha a mais que o njord escreveu antes de o plugin ter essa
   entrada). Nenhum é "manter por natureza": o balde `fica` do passo 3 já
   separa esses (rule de stack de verdade, guarda só do repo, guarda/script
   vendorizado por definição). Só a leitura de cada `LOCAL` diz se ele é uma
   correção que vale subir à fonte, um padrão para levar junto ao atualizar,
   ou descartável mesmo; qual decisão cabe a cada arquivo é trabalho da sessão
   que está migrando, não deste guia.

   Três regras para quem for manter uma guarda:

   - **Se o conserto de uma guarda que você vai manter já está em andamento
     num PR à parte, mexendo nos mesmos arquivos, não duplique o conserto
     aqui.** Espere esse PR mergear, rebase a migração em cima dele e resolva
     os arquivos que colidem com uma tabela no topo do seu próprio PR (arquivo,
     o que cada PR faz ali, qual versão fica) em vez de reescrever a guarda
     duas vezes em paralelo.

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

     No macOS o defeito comum nem chega ao `exit 1`. Cópias antigas extraem o
     payload com `grep -oP`, e o `/usr/bin/grep` do BSD recusa `-P`: a variável
     sai vazia e a guarda termina `exit 0` sem avaliar padrão nenhum, com
     `grep: invalid option -- P` no stderr e **sem** imprimir "BLOCKED". Um
     `grep -oP` numa guarda vendorizada é, sozinho, esse defeito (foi o caso das
     três guardas de `Bash`/`Edit` do website e do njord-front). Rode o hook
     sempre como `bash <hook> < payload.json`, nunca testando a extração na
     shell da sessão: ali o `grep` do Claude Code é uma função que chama um
     `ugrep` embutido, que **aceita** `-P`, e o teste mente a favor da guarda.

     Testando especificamente o `protect-main.sh`: um repo descartável recém
     `git init -b main`, sem nenhum commit, dá **falso `exit 0`**, mesmo já
     na branch `main`. Sem commit a branch está "unborn", `git rev-parse
     --abbrev-ref HEAD` devolve o literal `HEAD` no lugar de um nome de
     branch, isso nunca bate contra a lista de branches protegidas, e a
     guarda deixa passar sem bloquear, não porque decidiu que era seguro. Dê
     ao repo descartável pelo menos um commit numa branch com nome protegido
     (`main`, por exemplo) antes de rodar o payload, ou o teste passa sem ter
     testado nada.
   - **Ao atualizar uma guarda do repo a partir do `baseline/hooks/`, leve
     junto os padrões que só o repo tinha.** Uma guarda de arquivos críticos
     pode proteger caminhos que o baseline não conhece (uma pasta de
     migrations do ORM do repo, um arquivo de schema gerado). Copiar o
     baseline por cima apaga essa proteção em silêncio. É exatamente o aviso
     "conteúdo difere" que o passo 3 já anexa a todo hook do balde `fica` que
     é do repo por definição (`protect-critical.sh`, no njord-back).
   - **Rule com o mesmo nome de arquivo de uma rule do harness perde o
     caminho para o `--adopt`, não ganha dele.** As duas carregam juntas
     enquanto convivem (rules são descobertas de forma recursiva, então
     `.claude/rules/nome.md` e `.claude/rules/harness/nome.md` somam, não
     competem), mas o `--adopt` deduplica movendo a cópia do repo para
     `.claude/rules/nome.md.pre-harness`, e só a do harness fica visível
     depois. Se o conteúdo da rule do repo precisa sobreviver (o caso comum
     do balde `LOCAL`: uma rule de stack que colide de nome com uma do
     harness), mova-o para outro nome de arquivo ou para o `AGENTS.md` antes
     de rodar `--adopt`, nunca depois.
6. **Edite o `settings.json` commitado do repo:** remova as entradas dos
   hooks portáveis que **estiverem** registradas ali, nem todo repo registrou
   os mesmos. Os candidatos, conferidos no `install-harness.sh` deste
   harness, são nove: em `Bash`, `block-secrets.sh`, `protect-main.sh`,
   `protect-machine-config.sh` e `log-edit.sh`; em
   `Edit|Write|MultiEdit|NotebookEdit`, `protect-harness.sh`,
   `protect-machine-config.sh` e `log-edit.sh` (estes dois últimos
   registrados nos dois matchers, por isso a soma dos nomes passa de nove);
   `log-agent.sh` (`SubagentStop`); e `check-handover.sh`, `check-index.sh`
   e `check-baseline.sh` (`SessionStart`); no njord-back, por exemplo,
   `log-edit.sh` e `check-baseline.sh` nunca estiveram commitados ali, não
   tem entrada para tirar.

   **Só remova a entrada de um hook do repo que o plugin de stack também
   registra depois de provar, com payload, que a cópia instalada do plugin de
   fato bloqueia.** A seção "Plugins de stack" (abaixo) diz quando um plugin
   registra hook próprio; rode o mesmo teste de `exit 2` do passo 5 contra o
   caminho do hook **dentro do cache instalado do plugin**
   (`~/.claude/plugins/cache/<marketplace>/<plugin>/<versão>/hooks/<nome>.sh`),
   não contra o do repo. Se a cópia do plugin ainda sai `exit 1`, mantenha as
   duas guardas registradas: rodar duas vezes não faz mal, e o repo ficar sem
   nenhuma que bloqueie faz.

   Mantenha as guardas que são do repositório, e registre o
   `protect-harness.sh` e qualquer guarda de edição do repo que continuar
   registrada no mesmo matcher amplo, `Edit|Write|MultiEdit|NotebookEdit`
   (`protect-harness.sh` fica nos dois lugares de propósito, não é removido).
   Uma cópia anterior a essa guarda não tem o arquivo, e o passo 3 não o
   aponta (ele só classifica o que está versionado): se
   `.claude/hooks/protect-harness.sh` não existe, copie-o de `baseline/hooks/`
   (é `REPO_HOOKS`, o mesmo que o `install.sh` faria) antes de registrar.
   Um repo antigo costuma ter essas guardas só em `Edit|Write`, deixando
   `MultiEdit` e `NotebookEdit` passarem por fora; alinhe o matcher ao mesmo
   tempo em que edita a entrada, não depois.
   Tirar a entrada sem apagar o arquivo do hook deixa uma cópia velha no
   repo: se o balde do passo 3 marcou esse hook como `sai`, o arquivo sai
   junto.

   **Para cada caminho que o `AGENTS.md`/`CLAUDE.md` do repo diz estar
   protegido, rode um payload contra a guarda registrada de verdade e
   confirme `exit 2`**, o mesmo teste do passo 5, não só contra o texto da
   doc. Se quem bloqueia de fato é a guarda do plugin e não a que a doc
   credita, corrija a atribuição ali: uma doc que credita a guarda errada
   sobrevive tranquila até o dia em que a guarda de verdade some (plugin
   desabilitado, versão sem o hook) e ninguém percebe.
7. **Suba as remoções, nunca com `git add -A`, e escolha `git rm` ou
   `git rm --cached` conforme o que o `--adopt` fez com aquele caminho.** Nas
   skills e agents que colidiram e nas rules e commands individuais postos de
   lado (ver passo 3), o caminho original agora é um link **para dentro do clone
   do harness**. Ali, `git add` recusa na hora (`fatal: pathspec ... is beyond a
   symbolic link`) e um `git rm` normal apagaria o arquivo real do seu clone, não
   uma cópia: use `git rm --cached <caminho>`, que só tira do índice e não toca
   o working tree. Um arquivo `fica` em `.claude/skills/` (skill do próprio repo)
   não foi tocado pelo `--adopt` e não entra em nenhum dos dois. Já `.claude/hooks`, `.claude/docs` e
   `.claude/scripts` o `--adopt` não toca: a cópia antiga continua sentada no
   disco como um arquivo comum, e `git rm --cached` ali deixaria essa cópia
   solta e sem rastreamento; use `git rm` normal, que apaga do índice e do
   disco de uma vez, sem sobra.

   Se o arquivo `sai` é o último de uma pasta que o repo anuncia como sua, a
   pasta some junto. No website, `docs/libs/example-lib.md` era `sai` (o harness
   entrega esse caminho) e era o único arquivo de `.claude/docs/libs/`, a pasta
   que `AGENTS.md` e `CLAUDE.md` apontam para "como este projeto usa cada lib".
   A remoção está certa; o passo 8 é que precisa reapontar quem a cita (o
   modelo passa a ser `.claude/docs/harness/libs/example-lib.md`).

   Com o critério do passo 3, `check-snapshot-on-session.sh`,
   `scripts/check-snapshot.sh` e `protect-critical.sh` já ficam no balde
   `fica` (são `REPO_HOOKS`/`REPO_SCRIPTS` por definição), não em `sai`: a
   lista de exceções que este guia mantinha para esses três não é mais o
   único mecanismo que os protege, o balde já os separa sozinho.

   Ainda assim, antes de apagar qualquer arquivo do balde `sai`, procure com
   `grep` quem, entre os arquivos que ficam, aponta para ele. Isso continua
   valendo como rede de segurança, para o caso de um repo cujo `install.sh`
   seja mais velho que o `REPO_HOOKS`/`REPO_SCRIPTS` de hoje, ou de qualquer
   outra referência que o critério automático não previu:
   ```bash
   grep -rn "check-snapshot.sh" .claude --include='*.sh'
   ```
   No njord-back isso mostra que `.claude/hooks/check-snapshot-on-session.sh`
   chama `.claude/scripts/check-snapshot.sh` (`if [[ ! -x
   ".claude/scripts/check-snapshot.sh" ]]; then exit 0; fi`): removido em
   silêncio, o hook para de avisar sobre snapshot velho sem dar erro nenhum.
   Neste repo, como os dois já caem em `fica`, o `grep` não muda a decisão;
   ele importa quando o balde `sai` incluir um arquivo que outro arquivo
   mantido ainda referencia por caminho.

   Testado num repo descartável: as pastas e arquivos `.pre-harness`, e os
   links que o `--adopt` cria, já estão listados no `.git/info/exclude` (o
   próprio instalador escreve esse bloco), então `git add -A` não os sobe por
   engano. O perigo de `-A` aqui é outro: ele é cego ao que é remoção do
   `--adopt` e ao que é qualquer outra mudança que por acaso esteja solta na
   working tree naquele momento, sobe tudo junto sem chance de revisar item a
   item. `git rm`/`git rm --cached`, um caminho de cada vez, é o que garante
   que o commit tem exatamente as remoções do passo 7 e nada mais. Confira o
   `git status` inteiro antes de commitar de qualquer forma.
8. **Corrija a documentação do repo que aponta para caminhos que agora vêm do
   harness ou do plugin** (por exemplo, um script que estava em
   `.claude/scripts/spec-worktree.sh` passa a ser
   `.claude/scripts/harness/spec-worktree.sh`; uma skill que passou a vir do
   plugin de stack não tem mais caminho dentro do repo). Comece fora de
   `.claude/`: no website, a maior parte dos ponteiros quebrados estava em
   `AGENTS.md`, `CLAUDE.md` e `docs/` (um guia de setup mandava renomear
   arquivos que agora são link para o clone do harness). O `check-index.sh` só
   olha o índice do `CLAUDE.md` e ponteiros dentro de rules, skills, agents e
   scripts: `AGENTS.md` e `docs/` apodrecem em silêncio mesmo com `--strict`
   verde, então procure os caminhos que saíram:
   ```bash
   git grep -nE '\.claude/(commands|skills|agents|rules|docs|scripts|hooks)/' -- ':!.claude'
   ```
   Confira também o `.gitignore`: o `--adopt` registra o `log-edit.sh` e o
   `log-agent.sh`, que escrevem `.claude/tool-log.txt`, `.claude/agent-log.txt`
   e `.claude/.agent-log-consumed` na primeira chamada. Um repo cujo
   `.gitignore` é anterior a esses hooks fica com um arquivo novo não
   rastreado logo depois de adotar, no diretório que o passo 7 manda revisar.

   Um repo que adotou com uma versão antiga do `install.sh` provavelmente tem
   `.claude/agent-memory/` no `.gitignore`: remova essa linha. A memória de um
   subagent com `memory: project` é versionada de propósito (vai no diff da
   feature branch e é revisada com o PR, igual a qualquer outro arquivo); só
   `memory: local` fica em `.claude/agent-memory-local/`, que continua fora do
   git. Se um agent de plugin rodou por engano no repo errado e deixou memória
   que não faz sentido aqui, apague o arquivo, não commite.

   A exceção é repositório **público**: a memória dos agents registra o que
   eles viram em outros repos (nomes, caminhos, decisões de repos privados),
   e versionar isso num repo público é vazamento. Nele, mantenha
   `.claude/agent-memory/` no `.gitignore`, como este próprio harness faz.

   Revise também os arquivos que ficam fora dos sete diretórios classificados
   no passo 3:
   `.claude/*.md` soltos (um `.claude/README.md` de época costuma descrever a
   cópia vendorizada que acabou de sair) e `.claude/settings.json.example`,
   que costuma registrar os mesmos hooks antigos que o passo 6 acabou de
   tirar do `settings.json` de verdade. Os dois ficam errados em silêncio se
   ninguém olhar, porque nada nesta lista de passos os toca sozinho.
9. **Verifique:**
   ```bash
   "$HARNESS/install-harness.sh" --status
   bash .claude/scripts/harness/check-index.sh --strict
   ```
   O `check-index.sh` ignora pastas `*.pre-harness` e arquivos gitignorados, e
   acha docs em subpasta, então rodar isso com as `.pre-harness` ainda no
   disco (passo 10) dá `--strict` **0**; se der outra coisa, é um ponteiro de
   verdade, não a sobra esperada.

   Antes de rodar a suíte de testes do próprio repo, prepare-o como se fosse
   um clone novo, não o ambiente que já está aberto: se o repo tem um
   `script/setup` executável, rode-o; senão siga o setup do `AGENTS.md` do
   repo (versão do runtime a partir do `.nvmrc` ou equivalente, install,
   qualquer geração de código que o setup exija). No njord-back, sem rodar o
   `prisma generate` que o `AGENTS.md` pede antes dos testes, 6 suítes
   unitárias nem chegam a carregar, o que parece falha da migração e não é.

   Este passo pressupõe um setup sem segredo e uma suíte de testes; nem todo
   repo tem os dois:

   - **Setup que pede variável que você não pode ler** (chave de API,
     credencial de banco): exporte um placeholder só para o setup rodar
     (`export STRIPE_KEY=placeholder`, por exemplo) e confira, pelo `git diff`,
     que a migração não tocou nenhum código que os testes exercitam de
     verdade; segredo de verdade não entra no valor de teste nem no commit.
   - **Falha que já existia antes da migração** não é culpa dela: rode a
     mesma suíte na branch base (`git stash` ou um segundo checkout em
     `origin/<branch-de-integração>`) e compare. Só o que piorou entre as
     duas é seu.
   - **Sem suíte de testes no repo**, use o gate que o `AGENTS.md` dele
     declara (o comando que `verify-before-done` rodaria), não invente um.
   - **Um comando de config que ecoa segredo interpolado** (`docker compose
     config` sem `-q`, por exemplo, imprime o `.env` inteiro resolvido no
     stdout) é a forma errada de só validar sintaxe. Prefira a forma
     silenciosa do mesmo comando (`docker compose config -q`, que só retorna
     o código de saída) quando só a validação importa.
10. **Um PR só com as remoções.** As pastas `.pre-harness` só podem sumir de
    verdade depois do merge desse PR. Enquanto a migração estiver feita mas
    não commitada, vale o mesmo aviso do bloco acima: não commite, não faça
    merge, não dê pull nesse estado.

### 4. Projeto novo, ainda sem contexto

```bash
cd ~/Sites/projeto-novo
"$HARNESS/install.sh"          # AGENTS.md, CLAUDE.md, docs/, specs/, guardas
"$HARNESS/install-harness.sh"  # o método
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

### 5. O repo já migrou, e o seu checkout tinha a cópia antiga

Terceiro caso, diferente dos dois acima: ninguém está migrando agora, alguém já
migrou (rodou a seção 3 e removeu a cópia vendorizada de `.claude/skills`/
`.claude/agents` do controle de versão remoto). O seu checkout local ainda
tinha essa cópia rastreada quando você deu `git switch`/`git pull`. O git
remove do disco os arquivos que ele rastreava, mas às vezes a pasta continua
existindo, porque sobrou dentro dela algo que o git nunca rastreou, por
exemplo o `.DS_Store` do Finder no macOS: git não apaga diretório com
conteúdo.

Com o instalador de hoje, que linka skills e agents um a um, essa sobra **não
atrapalha mais**: uma pasta `.claude/skills` real é o layout esperado, e o
instalador só para quando um item dela tem o nome de um item do harness. Rodar
`install-harness.sh` sem `--adopt` resolve.

Se ele parar mesmo assim, é porque você tem uma skill ou agent **com o nome de um
do harness**, quase sempre uma cópia velha que o `git pull` não apagou por causa
de uma sobra dentro dela. Confira antes de rodar `--adopt`:

```bash
ls -la .claude/skills/<nome>
git ls-files .claude/skills/<nome>
```

Se `git ls-files` não listar nada, é sobra: `--adopt` põe só esse item de lado,
em `.claude/skills.pre-harness/<nome>`, e o instalador não imprime o aviso de
"arquivos rastreados foram deletados", porque não seria verdade. Se for conteúdo
seu com um nome que colide, renomeie antes: com `--adopt` ele sai de cena enquanto
o harness estiver linkado.

**Checkout que já estava no layout antigo** (a pasta inteira como um link só,
de um instalador anterior): rode o instalador de novo, sem flag. Ele troca o
link da pasta por links um a um e devolve, da `.claude/skills.pre-harness/` que
o `--adopt` antigo criou, o que **o git rastreia** e o harness não entrega, ou
seja, as skills do próprio repo que o link antigo escondia. O que o git não
rastreia (uma cópia vendorizada que já saiu do repo) continua lá, para você
apagar quando quiser.

### Windows

Se você estiver no **Git Bash nativo**, o `ln -s` não cria symlink sem **Modo de
Desenvolvedor** ligado (ou terminal como admin). O instalador detecta isso: ele
tenta o link, confere se de fato virou link e, se não virou, **copia e avisa**.

```
COPIED     .claude/skills/explore (this platform would not make a symlink)
```

Um por item, não a pasta inteira: desde que skills e agents passaram a linkar
um a um (seção "Ligue num projeto", acima), essa é a mensagem por skill ou
agent, repetida uma vez para cada um que o harness entrega.

Uma cópia funciona igual no dia a dia, mas **não acompanha o checkout**. Então
para você, `git pull` sozinho não atualiza nada: **rode o instalador de novo
depois de puxar.** O `--status` diz quais entradas são cópia. E o `check-baseline.sh` compara a sua cópia com o harness na abertura da sessão: se ela ficou para trás, ele avisa e manda rodar o instalador de novo. Você não precisa lembrar sozinho.

Ligar o Modo de Desenvolvedor no Windows, ou usar WSL, devolve o comportamento
de symlink e o `git pull` volta a bastar.

### Atualizar

```bash
git -C "$HARNESS" pull
```

Isso atualiza na hora, em todo projeto que você linkou, o conteúdo de tudo que
já está linkado, porque todos leem os mesmos arquivos. Duas exceções pedem rodar
o instalador de novo em cada projeto depois do pull:

- uma skill ou agent que o harness **criou ou renomeou** (o link é um por item, e
  o item novo ainda não tem o dele);
- o `--status` diz `COPIED` (cópia não acompanha o checkout).

O `check-baseline.sh` avisa as duas no início da sessão, com o nome do item.

### Remover

```bash
cd ~/Sites/algum-projeto
"$HARNESS/install-harness.sh" --unlink
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
por chamada. Ao migrar um repo que já tinha essa cópia (seção 3, "Se o repo já
tem uma cópia antiga do harness", acima), só pare de registrar a cópia do repo
depois de confirmar com payload que a cópia instalada do plugin bloqueia de
verdade (passo 6 daquela seção).

**A cópia instalada do plugin pode ficar velha, e nada avisa sozinho.** O
Claude Code guarda o plugin em cache por versão, em
`~/.claude/plugins/cache/<marketplace>/<plugin>/<versão>/`, e identifica a
instalação pelo campo `version`, não pelo commit: se um plugin receber commits
de conteúdo sem subir de versão, a cópia instalada não muda mesmo depois do
marketplace mudar. Foi o que aconteceu com o `backend-nest`: recebeu três
commits de conteúdo ainda em `0.1.0`, antes de alguém notar. Hoje o
marketplace do njord tem um job de CI, `plugin-versions` (PR #16), que recusa
mudança de conteúdo de um plugin sem subir a versão junto, então esse cenário
específico não deveria se repetir ali; ainda vale para qualquer marketplace
sem esse job.

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
`update` não trazia conteúdo novo, mesmo com o marketplace à frente. Quando a
versão subiu (`backend-nest` foi para `0.2.0` em 15/09), o mesmo comando
trouxe: `installed_plugins.json` mostra a instalação de escopo `user` hoje em
`0.2.0`, `gitCommitSha` atualizado, confirmando que o mecanismo funciona assim
que a versão sobe.

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
| **`lean`** | modelo forte, mudança que cabe na cabeça de um especialista só. Um `plan.md` no lugar de `spec.md` mais `tasks.md` (problema, fluxo, o que muda, superfície, portas sem volta, critérios de aceite), um `checks.md` emparelhando cada claim com a prova dela, um despacho que constrói do seu jeito, um subagent fresco que avalia cada claim e fecha com `verify-gate.py`, uma revisão, um PR. Mesmos travamentos do `orchestrate` (porta sem volta, branch protegida, gate vermelho três vezes). Use `orchestrate` para modelo mais fraco, trilha de checkbox auditável, ou mudança grande demais para um especialista só |
| **`verify-before-done`** | antes de dizer que algo está pronto. Se o repo tem um `script/test` executável na raiz, roda ele; senão descobre install, typecheck, build e testes do `AGENTS.md` **deste** repo. Depois escreve um relatório de evidências em `.claude/verification/` e valida com `verify-gate.py`: comandos com exit code, claims com `file:line` ou comando como prova |
| **`verify-ui`** | a mudança toca uma tela (página, componente, template de email, PDF, tela de TUI). Dirige a UI de verdade, na ordem que o repo/sessão tiver (browser do próprio agent tool, MCP do Playwright, script do repo), e escreve a claim provada no mesmo relatório do `verify-before-done`: o fluxo percorrido, as asserções checadas e o caminho do screenshot como prova. Sem driver disponível, reporta a claim como não provada em vez de afirmar que funciona. Não é para mudança pura de backend/API |
| **`diagnosing-bugs`** | bug difícil ou regressão de performance. O gate é um loop de feedback reprodutível **antes** de qualquer hipótese |

### Fechando

| skill | use quando |
|---|---|
| **`checkpoint`** | você quer um ponto de salvamento confiável. Roda o gate, commita e dá push (padrão, nunca no vermelho, nunca em branch protegida) |
| **`documenting-domains`** | uma feature subiu e o conhecimento precisa sobreviver à spec. Escreve `CLAUDE.md` aninhados |
| **`handover`** | a sessão está longa ou você vai parar. Reconcilia o `tasks.md` contra a realidade, descreve o que **é verdade** (nunca o que fazer em seguida), **sempre grava um arquivo** (na spec ativa, ou em `.claude/handovers/` quando não há spec), imprime um bloco copiável e manda limpar |
| **`status`** | "onde eu estou?" Cartão de saúde somente-leitura: spec ativa, tasks abertas, gates, branch |
| **`postmortem`** | um incidente terminou (outage, vazamento cross-tenant, deploy falho) e precisa virar aprendizado, não culpa. Classifica severidade (SEV1-SEV4), reconstrói a timeline, separa causa imediata/subjacente/sistêmica, e lista as 3-5 mudanças que teriam evitado ou detectado, marcando cada uma como confirmada ou avaliação. Não é para depurar um bug ainda ativo, isso é o `diagnosing-bugs` |

### Sobre o próprio harness

| skill | use quando |
|---|---|
| **`analyze-codebase`** | uma vez, ao adotar num projeto existente. Detecta stack e convenções, gera a documentação inicial e o repo map |
| **`refresh-snapshot`** | você quer um export manual do Repomix (um arquivo só) para dar a outra ferramenta sem acesso ao filesystem. Não é o mecanismo de contexto panorâmico do harness, esse é o repo map, sempre atualizado sozinho (ver ADR 0003) |
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
| `code-reviewer` | revisa a implementação contra a spec, o plano e as tasks ativas. Classifica cada achado por severidade (`blocker`/`should-fix`/`nit`/`pre-existing`) com ID estável, então uma segunda rodada converge em vez de repetir |
| `reviewer` | revisão de branch inteira em nível sênior, roda a verificação do repo e pode abrir o PR. Mesma taxonomia de severidade e contrato de convergência do `code-reviewer`, lendo a rodada anterior nos comentários do próprio PR |
| `implementer` | implementador portátil de fallback: usado só quando não existe specialist de stack para o trabalho. Lê o `AGENTS.md`, as rules e o código ao lado da mudança antes de escrever, e nomeia no relatório qual specialist deveria existir |
| `tester` | escreve e roda testes usando o framework **deste** repo, descoberto do tooling |
| `researcher` | mergulha numa lib ou API externa. Mantém memória entre sessões |
| `security-auditor` | auth, segredos, validação de input. Barato e afiado, vale rodar antes de release |

---

## Rules e hooks

**Rules** carregam sozinhas conforme um glob `paths:`, então não custam nada até
serem relevantes. Cinco vêm no harness, mais um exemplo:

- `delegation.md`: sempre ligada. A thread principal coordena, os specialists implementam
- `git-workflow.md`: sempre ligada. Nome de branch, Conventional Commits, convenção de PR
- `resuming.md`: sempre ligada. Onde olhar antes de re-derivar contexto ao retomar (handover mais novo ou `tasks.md`, o que `check-handover.sh` já aponta no início da sessão)
- `specs.md`: em `specs/**`. Afirmações são verificadas contra código e git, nunca copiadas de prosa antiga
- `adr.md`: em `docs/decisions/**`. ADR é append-only, se supersede em vez de reescrever

**Rules se somam, não competem.** Como são descobertas de forma recursiva, uma
rule do harness em `.claude/rules/harness/` e uma do próprio repo em
`.claude/rules/` carregam as duas, mesmo quando têm o mesmo nome de arquivo: a
regra duplica em vez de uma vencer a outra. O `--adopt` é quem resolve essa
duplicata, pondo a cópia do repo de lado (`.claude/rules/<nome>.md.pre-harness`)
e deixando só a do harness ativa (ver passo 5 da seção "3. Se o repo já tem
uma cópia antiga do harness", acima, para o que fazer com o conteúdo antes
disso acontecer).

**Hooks** são proteções que rodam independente do que o Claude decidir. Os
portáveis são registrados pelo `install-harness.sh`, nove ao todo:
`block-secrets.sh`, `protect-main.sh`, `protect-harness.sh`,
`protect-machine-config.sh`, `check-handover.sh`, `log-agent.sh` e
`log-edit.sh` (de `baseline/hooks/`), mais `check-index.sh` e
`check-baseline.sh` (de `baseline/scripts/`, registrados do mesmo jeito, no
`SessionStart`; `check-handover.sh` também é `SessionStart`, mas mora em
`baseline/hooks/`, não em `baseline/scripts/`).

Dois **não** entram junto com o método de propósito, porque são guardas que o
repositório deve a todos, inclusive a quem nunca instalou isto: o `install.sh`
os copia para dentro do repo, o `install-harness.sh` nunca os registra.
`protect-critical.sh` e `check-snapshot-on-session.sh` ficam só na cópia
porque dizem respeito ao repositório (lockfile, migration, snapshot), não a
uma máquina.

`protect-harness.sh` está nas duas listas **de propósito**, não é uma exceção
esquecida: é a própria governança do harness, e a regra dela é o critério, não
a lista de padrões (essa está no `CLAUDE.md`). Um agente pode mexer no que vai
aparecer num review, seja no repo onde a sessão está rodando, seja num projeto
comum diferente (ex.: replicar uma mudança rastreada de `.claude/settings.json`
num terceiro repo, a partir de uma sessão aberta aqui). O que continua
bloqueado, de qualquer sessão, é editar o PRÓPRIO checkout do harness a partir
de outro repo (esse fica vivo em todo projeto linkado sem passar por commit
nenhum, ver o cabeçalho de `protect-harness.sh`) e editar o que é gitignorado,
próprio ou alheio, e por isso invisível a qualquer review. Por isso o
`install.sh` também o vendoriza (`REPO_HOOKS`, mesmo array dos dois acima),
como rede de segurança para o caso de `install-harness.sh` nunca ter rodado
naquele repo.

Um terceiro fica de fora só do método, por um motivo diferente:
`block-new-em-dashes.sh` aplica uma preferência tipográfica **deste**
repositório, não uma convenção portátil. Nem o `install.sh` nem o
`install-harness.sh` o propagam para outro projeto; ele está registrado só no
`settings.json` commitado deste harness.

---

## Scripts com permissão própria

Skills e hooks portáveis chegam prontos para uso: symlink e, no caso dos
hooks, já registrados. Um script de `baseline/scripts/` que faça algo sensível
o bastante para merecer consentimento explícito do repositório é diferente:
chega pelo mesmo symlink (`.claude/scripts/harness/<nome>.sh`), mas o harness
nunca concede a si mesmo permissão para rodá-lo. Essa concessão é sempre do
`.claude/settings.json` **commitado do próprio repositório**, nunca do
`settings.local.json` que o harness gerencia.

`env-set.sh` é o primeiro caso assim. Faz upsert de UMA chave num arquivo
`.env` sem nunca imprimir o conteúdo do arquivo (o valor entra por stdin,
nunca por argumento, então não fica em argv, histórico de shell ou transcript
de agente). Existe justamente para o caso em que uma sessão precisa GRAVAR um
segredo novo mas continua proibida de LER o arquivo inteiro. Para habilitar,
o repo adiciona ao seu próprio `.claude/settings.json`:

```json
{
  "permissions": {
    "allow": ["Bash(.claude/scripts/harness/env-set.sh:*)"],
    "deny": ["Read(.env)", "Read(.env.local)", "Read(.env.*.local)"]
  }
}
```

`Read(.env)` continua negado. O deny troca um `Read(.env.*)` genérico, que
bloquearia até a leitura de uma variante sem segredo como `.env.example`,
pelas variantes locais que de fato guardam segredo. Ver o cabeçalho de
`baseline/scripts/env-set.sh` e `baseline/scripts/README.md` para as
garantias do script (nunca imprime o arquivo, recusa o backup se ele não
ficaria gitignorado, nunca encolhe o arquivo). Essa edição no `settings.json`
commitado é sempre do repositório, feita uma vez: o harness não a faz por
você, do mesmo jeito que não toca em nenhuma outra linha desse arquivo.

---

## Quando algo der errado

**O `/orchestrate` sumiu, as skills não existem.** Os links quebraram, quase
sempre porque o clone do harness foi movido ou apagado. **O Claude Code não dá
erro nisso**: as skills simplesmente não estão lá e a sessão parece normal. O
`check-baseline.sh` avisa no início da sessão. Resolve rodando o instalador de novo.

```bash
"$HARNESS/install-harness.sh" --status   # o que está linkado aqui
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
