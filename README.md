# claude-spec-driven-template

**Um template prático de repositório para estruturar projetos habilitados por IA**
**com instruções compartilhadas, configuração específica do Claude, subagents, skills, hooks e desenvolvimento guiado por spec.**

![Status](https://img.shields.io/badge/status-active-2563eb?style=for-the-badge)
![Type](https://img.shields.io/badge/type-template-111827?style=for-the-badge)
![Stack](https://img.shields.io/badge/stack-agnostic-0f766e?style=for-the-badge)
![Learn](https://img.shields.io/badge/learn-course-1d4ed8?style=for-the-badge)
![AGENTS.md](https://img.shields.io/badge/AGENTS.md-supported-5b21b6?style=for-the-badge)
![Claude](https://img.shields.io/badge/claude-configured-d97706?style=for-the-badge)
![Superpowers](https://img.shields.io/badge/superpowers-ready-0891b2?style=for-the-badge)
![License](https://img.shields.io/badge/license-MIT-16a34a?style=for-the-badge)

---

## Visão geral

`claude-spec-driven-template` é um template agnóstico de stack para estruturar repositórios em torno de agents de codificação de IA. Ele mostra onde cada arquivo de instrução de IA pertence, como as camadas interagem, e como combiná-las com desenvolvimento guiado por spec.

Isso não é só uma árvore de pastas. É uma referência funcional cuja própria configuração de IA é parte da lição.

Ele combina:

- instruções compartilhadas de agent em [`AGENTS.md`](./AGENTS.md)
- orientação específica do Claude em [`CLAUDE.md`](./CLAUDE.md)
- orientação específica do Copilot em [`.github/copilot-instructions.md`](./.github/copilot-instructions.md)
- schemas e contratos compartilhados em [`ECOSYSTEM.md`](./ECOSYSTEM.md)
- workflow de contribuição em [`CONTRIBUTING.md`](./CONTRIBUTING.md)
- histórico de mudanças em [`CHANGELOG.md`](./CHANGELOG.md)
- configuração interna do Claude em [`.claude/`](./.claude/)
- documentação do projeto voltada a humanos em [`docs/`](./docs)
- features guiadas por spec em [`specs/`](./specs)
- exemplos de CLAUDE.md aninhado em [`src/`](./src)
- um curso guiado em [`LEARN.md`](./LEARN.md)
- passo a passo de setup em [`docs/guides/initial-setup.md`](./docs/guides/initial-setup.md)

---

> **Vai adotar isso na sua própria máquina?** Comece por [`ADOPTING.md`](./ADOPTING.md) (em português) — instalação, e qual skill usar em cada momento. Este arquivo explica a estrutura; aquele te deixa rodando.

## Comece aqui

| você quer | leia |
|---|---|
| **instalar e usar** | [`ADOPTING.md`](./ADOPTING.md) — os dois comandos, e qual skill para qual momento (pt-BR) |
| **entender as ideias** | [`LEARN.md`](./LEARN.md) — o curso guiado |
| **saber onde uma instrução vai** | [`docs/reference/where-does-it-go.md`](./docs/reference/where-does-it-go.md) |
| **ver como as camadas se encaixam** | [`docs/reference/layers.md`](./docs/reference/layers.md) |
| **adotar num codebase existente** | [`docs/guides/brownfield.md`](./docs/guides/brownfield.md) |
| **rodar o pipeline de feature** | [`docs/workflows/feature-pipeline.md`](./docs/workflows/feature-pipeline.md) |

## Em que ele está apostando

1. **Arquivos de instrução têm papéis distintos.** Nem tudo pertence ao `CLAUDE.md`.
2. **O custo de contexto é a restrição.** O que carrega sempre precisa ser pequeno; o que é detalhado carrega sob demanda.
3. **Specs são versionadas ao lado do código** e são a fonte de verdade quando discordam.
4. **Agents, skills, rules e hooks são ferramentas diferentes.** Um hook roda o que o modelo decidir; uma rule só persuade.
5. **Uma guarda que ninguém vê falhar decai.** Por isso o harness se mede, veja [`baseline/docs/harness-baseline.md`](./baseline/docs/harness-baseline.md).

## Estrutura do projeto

```
├─ baseline/          O HARNESS — linkado por symlink nos projetos, nunca commitado
│  ├─ agents/           8 subagents (7 revisores/exploradores + implementer)
│  ├─ skills/          23 skills, um /nome cada, carregadas sob demanda
│  ├─ rules/            convenções com escopo de path, carregadas automaticamente
│  ├─ hooks/            guardas que rodam o que o modelo decidir
│  ├─ scripts/          check-index · check-baseline · spec-worktree · repo-map · check-snapshot
│  └─ docs/             só para IA: dispatching · context-engineering · harness-baseline
│
├─ .claude/           config própria deste repo — linka de volta para baseline/
├─ install-harness.sh Linka o harness num projeto que você escolher
├─ install.sh         Configura o contexto próprio de um projeto (copiado, commitado)
│
├─ specs/             spec.md · plan.md · tasks.md · lessons.md · deviations.md
├─ docs/              voltado a humanos: reference · guides · workflows · decisions
└─ src/example-module/CLAUDE.md   instruções aninhadas, carregadas por pasta
```

**Duas pastas, dois papéis.** `baseline/` é o harness — linkado por symlink nos
projetos que você escolher, nunca commitado lá. `.claude/` é a configuração
própria deste repositório, que linka de volta para `baseline/` para o harness
poder se usar. Um projeto que adota isso termina com a mesma forma.

Todo agent, skill, rule e hook está listado com seu propósito em
[`CLAUDE.md`](./CLAUDE.md), que é também o que o `check-index.sh` valida em
todo início de sessão.

## Usando este template

> **O caminho mais rápido é [`ADOPTING.md`](./ADOPTING.md)** — instale e saiba qual
> skill usar. Está em português; este arquivo explica a estrutura, aquele te
> deixa rodando.

### Os dois comandos, e por que existem dois

```bash
git clone https://github.com/dashdanilo/claude-spec-driven-template ~/Sites/harness

cd ~/Sites/some-project
~/Sites/harness/install.sh           # o CONTEXTO próprio do projeto — commitado
~/Sites/harness/install-harness.sh   # o MÉTODO — symlink, nunca commitado
```

**Contexto** é o que o repositório possui e compartilha com o time: `AGENTS.md`,
`CLAUDE.md`, `docs/`, `specs/`, e as guardas que um colega de time precisa ter,
tenha instalado algo ou não. É copiado, e é diferente em cada repo.

**Método** é como *você* trabalha: as skills, agents e rules. É linkado por
symlink a partir do seu clone, então um `git pull` lá atualiza todo projeto que
você linkou, de uma vez. Skills e agents são linkados um item por vez, então
uma skill ou agent que um repo versiona por conta própria continua carregando
ao lado dos do harness; o custo é que uma que o harness adicionar ou renomear
precisa rodar o instalador de novo, e o check de início de sessão avisa. Os
links vão para `.git/info/exclude`, então um colega clonando o repo não vê nada
e o CI não vê nada — **entrar é invisível para todo o resto, e sair não custa
nada.**

Numa plataforma que não cria symlinks (Git Bash no Windows sem o Modo de
Desenvolvedor), o instalador copia em vez disso, marca a cópia e avisa, e o
check de início de sessão te avisa quando essa cópia ficar defasada.

`--adopt` põe de lado um harness que um repo já copiou, `--unlink` devolve,
`--status` diz o que está linkado aqui.

Mais dois scripts, `script/setup` e `script/test`, são opcionais e seus para
escrever — o harness os chama quando existem (`spec-worktree` roda
`script/setup`, `verify-before-done` roda `script/test` como o gate) e não faz
nada sem eles. Veja [`docs/guides/script-setup-and-test.md`](./docs/guides/script-setup-and-test.md).

### Início rápido

Para um passo a passo (tanto para projetos novos quanto para codebases existentes), leia [`docs/guides/initial-setup.md`](./docs/guides/initial-setup.md).

### Opção 1: usar como template do GitHub

1. Clique em "Use this template" no topo da página do GitHub
2. Crie seu novo repositório
3. Siga [`docs/guides/initial-setup.md`](./docs/guides/initial-setup.md), Caminho 1 (projeto novo)

### Opção 2: adotar num projeto existente (brownfield)

Siga [`docs/guides/initial-setup.md`](./docs/guides/initial-setup.md), Caminho 2. Usa a skill `analyze-codebase` para gerar uma base de documentação a partir do seu código existente.

### Opção 3: adotar de forma incremental

Você não precisa de tudo de uma vez. Três níveis de adoção:

**Mínimo:** copie `AGENTS.md`, `CLAUDE.md` (stub), `.gitignore`, `.claudeignore`. Comece por aí.

**Prático:** adicione `.claude/settings.json`, `baseline/agents/code-reviewer.md`, e uma ou duas skills. Adicione `specs/` quando tiver sua primeira feature não trivial.

**Completo:** adote a estrutura completa. Use isso quando tiver um time e quiser workflows de IA consistentes entre as pessoas.

### Opção 4: instalar o Superpowers junto

O workflow guiado por spec deste template é compatível com o [plugin Superpowers](https://github.com/obra/superpowers):

```bash
# Dentro do Claude Code
/plugin install superpowers@claude-plugins-official
```

O Superpowers traz skills de brainstorming, writing-plans, subagent-driven-development, TDD e code-review que reforçam o fluxo guiado por spec.

---

## Atribuições

O template inclui contribuições da comunidade mais ampla do Claude Code:

- skill **[documenting-domains](baseline/skills/documenting-domains/SKILL.md)** de [douglasgomes98](https://github.com/douglasgomes98) - cria documentação local durável de domínio
- skill **[postmortem](baseline/skills/postmortem/SKILL.md)** adaptada de [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents) (MIT) - postmortem sem culpados após um incidente

A atribuição original é preservada inline em cada arquivo. Ao fazer fork deste template, mantenha a atribuição intacta se mantiver o arquivo.

## Licença

[MIT](./LICENSE)
