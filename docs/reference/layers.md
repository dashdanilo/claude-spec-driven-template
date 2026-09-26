# As quatro camadas

> Movido para fora do `README.md` para manter a porta de entrada curta. Linkado a partir de lá.

## Camada raiz compartilhada

A camada de explicação de mais alto nível. Estes arquivos são lidos por
humanos e agentes igualmente.

### [`README.md`](./README.md)

O ponto de entrada humano. Explica o que é o repositório, como as camadas se
encaixam, e como reutilizar a estrutura.

### [`AGENTS.md`](./AGENTS.md)

**Fonte da verdade para todos os agentes.** Instruções entre ferramentas
lidas por Codex, Cursor, Gemini CLI, Claude Code, GitHub Copilot, e qualquer
outro agente de codificação que suporte a convenção AGENTS.md. Contém a
stack, comandos, estrutura, convenções, fluxo de trabalho e não negociáveis:
tudo que um agente precisa para ser eficaz neste repositório.

### [`CLAUDE.md`](./CLAUDE.md)

**Stub para Claude Code.** Aponta para o AGENTS.md como fonte da verdade,
depois adiciona extras específicos do Claude que não se aplicam a outros
agentes: quais skills, subagentes, hooks e regras vêm com este projeto, mais
a localização de arquivos CLAUDE.md aninhados. Carregado automaticamente no
início de toda sessão do Claude Code.

Isso evita duplicação: a stack vive só no AGENTS.md. Atualize-a lá, todos os
agentes veem a mudança. O CLAUDE.md nunca fica fora de sincronia porque não é
dono desse conteúdo.

### [`.github/copilot-instructions.md`](./.github/copilot-instructions.md)

**Stub para GitHub Copilot.** Mesmo padrão do CLAUDE.md mas para o ecossistema
do Copilot (VS Code, JetBrains, Copilot Chat, Copilot Coding Agent, Copilot no
GitHub.com). Aponta para o AGENTS.md como fonte da verdade, depois adiciona
orientação específica do Copilot. Carregado automaticamente quando o Copilot
gera sugestões.

### [`ECOSYSTEM.md`](./ECOSYSTEM.md)

Schemas e contratos compartilhados entre superfícies do sistema. Crítico para
projetos multi-plataforma onde vários serviços precisam concordar sobre
nomes de campo, tipos e enums.

### [`CONTRIBUTING.md`](./CONTRIBUTING.md)

Como fazer mudanças sem quebrar o valor didático do repositório. Regras de
fluxo de trabalho, passos de validação, convenções.

---

## Camada interna do Claude

É isso que torna o Claude eficaz especificamente neste projeto.

### [`baseline/skills/`](./baseline/skills/)

Fluxos de trabalho reutilizáveis. Cada skill é um diretório com um
`SKILL.md`. O `description` no frontmatter é o gatilho: o Claude o lê e
auto-invoca a skill quando ela casa com uma tarefa.

Use skills quando você se pegar repetindo o mesmo processo de várias etapas entre sessões.

### [`baseline/agents/`](./baseline/agents/)

Subagentes são especialistas com janelas de contexto isoladas. Quando
invocados, eles exploram, leem e raciocinam na própria sessão, depois
retornam um resumo final. A conversa principal se mantém limpa.

Quatro templates inclusos:

- **`spec-reviewer.md`** audita toda spec antes de ela se tornar um plan (obrigatório; o `write-spec` o executa automaticamente)
- **`code-reviewer.md`** revisa a implementação contra o plan
- **`researcher.md`** investiga bibliotecas e acumula um `MEMORY.md` persistente
- **`security-auditor.md`** audita autenticação, segredos e validação de entrada

O campo `description` é o gatilho de auto-delegação. Convenção: inclua "Use
PROACTIVELY" ou "Use when..." para forçar delegação automática.

### [`baseline/rules/`](./baseline/rules/)

Convenções escopadas por caminho. O glob `paths:` no frontmatter determina
quando a regra carrega automaticamente. Sem `paths:`, a regra carrega sempre
(se tornando um CLAUDE.md escondido).

### [`baseline/docs/`](./baseline/docs/)

Conhecimento estático que só carrega sob demanda. Nada aqui carrega
automaticamente. Skills e agentes referenciam esses docs explicitamente
quando precisam deles.

Subpastas:

- **`libs/`** um doc por biblioteca externa ou integração, focado em como este projeto a usa (não os docs oficiais)
- **`decisions/`** registros de decisão de arquitetura, imutáveis depois de aceitos

### [`baseline/hooks/`](./baseline/hooks/)

Scripts que executam em eventos do ciclo de vida do Claude Code:
`PreToolUse`, `PostToolUse`, `Stop`, `SessionStart`, `Notification`.
Registrados em `settings.json`.

O exemplo `block-secrets.sh` é um hook de `PreToolUse` que impede o agente de
ler arquivos `.env` via Bash.

### [`.claude/settings.json`](./.claude/settings.json)

Permissões (`allow` e `deny`), registro de hooks, e modelo padrão. Faça
commit deste arquivo. Overrides pessoais vão em
`.claude/settings.local.json` (fora do git).

---

## Como as camadas de IA se conectam

- `README.md` apresenta o repositório e aponta para os lugares certos
- `LEARN.md` é o curso guiado
- `AGENTS.md` é a **fonte da verdade compartilhada** para qualquer agente de
  codificação (Codex, Cursor, Gemini CLI, Claude Code, GitHub Copilot): stack,
  comandos, estrutura, convenções, fluxo de trabalho
- `CLAUDE.md` é um **stub** apontando para o AGENTS.md, com adições
  específicas do Claude Code por cima (referências a skills, agentes, hooks)
- `.github/copilot-instructions.md` é outro **stub**, para o GitHub Copilot,
  mesmo padrão (aponta para o AGENTS.md, adiciona extras específicos do Copilot)
- `ECOSYSTEM.md` define schemas compartilhados entre superfícies
- `CONTRIBUTING.md` explica como mudar as coisas sem quebrar o valor didático
- `.claude/` contém configuração específica do Claude: skills, agentes, regras, docs, hooks
- `specs/` contém os artefatos guiados por spec: uma pasta por feature com spec + plan
- `src/<module>/CLAUDE.md` adiciona instruções aninhadas escopadas a uma única pasta (ainda conteúdo completo, não stub)

```
┌──────────────────────────────────────────────────────────────┐
│ Cross-tool source of truth (always loaded by all agents)     │
│   AGENTS.md  ECOSYSTEM.md                                    │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         ↓
                    CLAUDE.md (stub → AGENTS.md + Claude extras)
                         │
        ┌────────────────┼────────────────┐
        ↓                ↓                ↓
   .claude/         specs/             src/<module>/
   ├─ skills/     YYYY-MM-DD-slug/    └─ CLAUDE.md
   ├─ agents/     ├─ spec.md             (nested, full content)
   ├─ rules/      └─ plan.md
   ├─ docs/
   └─ hooks/
   (loaded on demand or by trigger)
```

---

## O que os hooks fazem aqui

Hooks são efeitos colaterais determinísticos sobre eventos do ciclo de vida
das ferramentas. Eles não carregam no contexto.

Este template traz estes hooks:

- **`block-secrets.sh`** intercepta chamadas da ferramenta `Bash` e bloqueia
  comandos que tentam ler arquivos `.env` ou imprimir variáveis de ambiente
  com nome de segredo
- **`protect-main.sh`** intercepta chamadas da ferramenta `Bash` e bloqueia
  `commit`, `push`, `merge`, `rebase` e `reset --hard` quando a branch atual é
  protegida (main, master, trunk, develop, production, release)
- **`protect-critical.sh`** intercepta chamadas de `Edit` e `Write` e bloqueia
  modificações nos próprios arquivos críticos do repositório (lockfiles,
  migrations aplicadas, código gerado, `.env`, `/secrets/`), exceto arquivos
  terminados em `.example`
- **`protect-harness.sh`** intercepta chamadas de `Edit` e `Write` e bloqueia
  modificações na própria superfície de governança do harness (seus hooks, a
  configuração que os registra, suas regras). O critério é revisabilidade:
  uma edição que vai aparecer no próprio diff deste repositório é permitida,
  uma edição que alcança o checkout de outro repositório ou um arquivo fora
  do git não é. Veja `CLAUDE.md` para o escopo exato
- **`check-snapshot-on-session.sh`** executa no início da sessão, verifica se
  uma exportação Repomix existe e está acima do orçamento de tamanho, e avisa
  se for o caso (nunca só por obsolescência, já que nada lê esse arquivo
  automaticamente; ver `docs/decisions/0003-repo-map-over-snapshot.md`)

Isso combina bem com hooks porque é:

- determinístico
- rápido (menos de 100ms)
- crítico para segurança
- impossível de esquecer quando adicionado como hook

Combina mal com hooks:

- qualquer coisa que precise carregar no contexto
- qualquer coisa que faça chamadas de rede
- qualquer coisa lenta ou não confiável

---

## O que `script/setup` e `script/test` fazem aqui

Nenhum dos dois vem com o template: são opcionais, escritos pelo time,
arquivos executáveis na raiz de um repositório *consumidor*. O harness só os
chama quando existem: o `spec-worktree` executa `script/setup` depois de
criar um worktree, e o `verify-before-done` executa `script/test` como gate
em vez de redescobrir comandos a partir do `AGENTS.md`. Um repositório sem
nenhum dos dois não é afetado; o passo é um no-op. Veja
[`docs/guides/script-setup-and-test.md`](../guides/script-setup-and-test.md).

---
