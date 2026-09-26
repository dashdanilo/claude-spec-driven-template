# Harness Score: medindo o harness deste repositório, e seus dois pontos cegos conhecidos

Para quem quer executar o [`harness-score`](https://github.com/paladini/harness-score)
contra este repositório (ou um projeto que linkou este harness) e entender o
número que ele imprime.

## Pré-requisitos

Node.js no `PATH` (a CLI é distribuída como um pacote npm; `npx` a busca, nada
para instalar antes). Nenhuma conta, nenhum acesso à rede necessário no
momento do escaneamento além da busca inicial via `npx`, nenhuma configuração
necessária para obter uma primeira pontuação.

## O que ele mede

O `harness-score` é uma CLI determinística, sem LLM, sem rede. Ele percorre o
sistema de arquivos de um repositório, verifica artefatos concretos (um
arquivo existe, faz parse, casa com um padrão), e reporta uma pontuação de 0
a 108 em seis dimensões, mapeada para um nível de maturidade de L0 (sem
harness) até L4 (auto-corretivo):

| Dimensão | Pontos | O que verifica |
|---|---|---|
| Context & Guides | 20 | Substância do `AGENTS.md`, regras escopadas com frontmatter |
| Skills & Commands | 17 | Arquivos `SKILL.md`, slash commands, definições de subagente |
| Hooks & Guardrails | 14 | Gate hooks (bloqueiam ações arriscadas), feedback hooks (lint/format ao editar) |
| Sensors & Feedback | 20 | Test runner, linter, checador de tipos, formatador, arquivos de teste reais |
| CI Feedback | 14 | Um pipeline que roda testes/lint/tipos em todo push, pre-commit instalado |
| Hygiene & Safety | 23 | `.gitignore`, sem segredos vazados, licença, lockfile, configuração de MCP segura |

Mesmo repositório, mesmo commit: mesma pontuação, sempre. É isso que permite
usá-lo como gate num job de CI (ver abaixo), e é exatamente por isso que ele
não consegue ver um harness entregue por symlink: ele não tem julgamento a
aplicar, só um conjunto fixo de padrões de caminho para casar contra os
arquivos que de fato percorreu.

## Executando

```bash
# relatório legível para humanos no terminal
npx harness-score

# legível por máquina
npx harness-score --json

# relatório em markdown, para um arquivo ou stdout
npx harness-score --md report.md
npx harness-score --md -

# gate de CI: falha se a pontuação mapear para abaixo de um nível dado
npx harness-score --min-level 2
```

Este repositório fixa uma versão específica no CI
(`.github/workflows/test.yml`, job `harness-score`) em vez de sempre buscar a
mais recente, e usa como gate `--min-level 2`, o nível que o próprio harness
deste repositório mantém hoje num clone limpo. Atualize a versão fixada
deliberadamente, depois de ler o CHANGELOG da nova versão, não como uma
atualização de dependência de passagem: a própria política de semver da
ferramenta permite que o *modelo* de maturidade (o que ganha pontos) mude numa
versão minor, então uma atualização sem revisão pode mover a pontuação deste
repositório por razões que não têm nada a ver com o que mudou aqui.

## Duas distorções que você vai encontrar nos próprios repositórios deste template

Mecanismo completo e a evidência no nível do código-fonte para ambas:
[`docs/decisions/0002-harness-visibility.md`](../decisions/0002-harness-visibility.md).
A versão curta, para você não precisar rededuzir:

### 1. Skills & Commands subestima todo repositório que linka este harness

Este harness é entregue por symlink (ver as ADRs 0001, 0003, 0004 do
repositório marketplace, citadas por completo na ADR 0002 acima). O varredor
de arquivos do `harness-score` deduplica pelo realpath canônico e mantém só o
primeiro diretório físico encontrado para um determinado destino, então:

- Um repositório que linka o harness com `install-harness.sh` (symlinks
  absolutos, por item, deliberadamente não commitados conforme a ADR 0003)
  recebe um veredito `outside-root-symlink`, e **todo o escaneamento** é
  marcado como incompleto, não só a dimensão de skills.
- Mesmo o próprio repositório deste template, onde
  `.claude/skills -> ../baseline/skills` é um symlink commitado, relativo e
  na raiz, ainda pontua 0/17: o varredor atribui todo arquivo dentro dele ao
  caminho canônico `baseline/skills/...`, que nenhuma das verificações
  `SKL-*`/`AGT-*` reconhece, já que procuram especificamente por um segmento
  de caminho `.claude/skills/`, `.cursor/skills/`, ou `.agents/skills/`.

Não existe flag de configuração que corrija isso (as chaves `extends`,
`rules` e `extraRoots` do `.harness-score.json` não remapeiam caminhos; não
existe flag `--follow-symlinks`). Trate uma pontuação baixa ou 0 em Skills &
Commands em qualquer repositório que use este harness como **esperado**, não
como um sinal de que o harness está faltando. Para ver o que de fato está
linkado num determinado checkout, execute `install-harness.sh --status` em
vez de confiar nesta dimensão.

### 2. Um worktree aninhado e obsoleto pode inflar a pontuação além do real

O `njord-back` pontuou um L4 enganoso, 99/108, em 2026-09-23. A causa: um
diretório `.claude/worktrees/<name>/` sobrando ainda guardava uma cópia
antiga, totalmente vendorizada (arquivos reais, não symlinks), de 48 skills e
20 agentes, de antes desse repositório adotar o harness baseado em symlink. Os
padrões de caminho do `harness-score` não têm âncora (eles casam
`.claude/skills/<name>/SKILL.md` *em qualquer lugar* da árvore, não só na raiz
do repositório), então essa cópia obsoleta e sem relação contou por completo
e empurrou a pontuação para L4 enquanto a configuração real, atual, de nível
superior do harness do repositório estava exatamente tão invisível quanto em
todo outro repositório dessa família (distorção nº 1, acima).

Antes de confiar numa pontuação alta, verifique se há qualquer coisa sob
`.claude/worktrees/`, `node_modules/`, ou qualquer outro checkout aninhado que
possa guardar sua própria cópia, possivelmente obsoleta, de arquivos do
harness. O `harness-score` não tem como saber qual cópia é "a real".

## Lendo um resultado honestamente

Dado que as duas distorções vão na mesma direção (skills/agentes
subcontados por symlinks, inflados por cópias vendorizadas obsoletas), uma
pontuação vinda dessa família de repositórios deveria sempre ser lida assim:

- **Context, Hooks, Sensors, CI, Hygiene:** confiáveis como reportadas, essas
  dimensões verificam arquivos que estão genuinamente commitados ou
  genuinamente ausentes, e nenhuma delas passa pelo comportamento de
  canonicalização de symlink acima.
- **Skills & Commands:** um piso, não um teto, num repositório que linka este
  harness. 0/17 não significa que nenhuma skill existe; significa que o
  `harness-score` não conseguiu ver as que existem.
- **Uma pontuação surpreendentemente alta:** vale uma verificação manual por
  uma cópia aninhada obsoleta antes de repeti-la em qualquer lugar, conforme
  o exemplo do `njord-back` acima.

## Próximos passos

- [`docs/decisions/0002-harness-visibility.md`](../decisions/0002-harness-visibility.md) - o registro completo da decisão, com citações no nível do código-fonte.
- [`ADOPTING.md`](../../ADOPTING.md) - como um projeto linka este harness (o mecanismo que causa a distorção nº 1).
- [o próprio guia do harness-score](https://paladini.github.io/harness-score/) - o modelo de maturidade e o catálogo completo de verificações, mantido upstream.
