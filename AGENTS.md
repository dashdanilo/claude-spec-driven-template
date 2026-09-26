# claude-spec-driven-template

> Fonte de verdade entre ferramentas. Lido por qualquer agent de codificação de IA: Codex, Cursor, Gemini CLI, GitHub Copilot, Windsurf, Aider, Claude Code, e outros que suportam a convenção AGENTS.md.
>
> Adições específicas de cada ferramenta vivem em seus próprios arquivos:
> - Claude Code: [`CLAUDE.md`](./CLAUDE.md) (stub apontando para aqui + extras específicos do Claude)
> - GitHub Copilot: [`.github/copilot-instructions.md`](./.github/copilot-instructions.md) (stub apontando para aqui + extras específicos do Copilot)
> - Gemini CLI: `GEMINI.md` (quando presente)
> - Cursor: `.cursor/rules/` (quando presente)

Um repositório template agnóstico de stack para estruturar projetos habilitados por IA em torno de desenvolvimento guiado por spec. Fornece layout de pastas, configuração de agent, skills, subagents, hooks e padrões de workflow que funcionam em Claude Code, GitHub Copilot e outras ferramentas compatíveis com AGENTS.md.

O repo em que você está trabalhando **é o próprio template**, não uma aplicação construída a partir dele. Não há código de runtime para executar, nenhum servidor para rodar, nenhum build para compilar. Contribuições a este repo evoluem o template que outros clonam e adotam.

## Natureza deste repositório

Este é um repositório pesado em documentação e leve em código. A maioria dos arquivos é markdown ou configuração. Shell scripts implementam hooks de ciclo de vida. Nenhum código-fonte além de exemplos ilustrativos.

Leia [`docs/CONSTITUTION.md`](./docs/CONSTITUTION.md) para a filosofia completa, os princípios e os limites deste projeto.

## Stack técnica

- **Documentação:** Markdown
- **Shell scripts:** Bash (compatível com POSIX quando possível)
- **Config:** JSON (`.claude/settings.json`)
- **Diagramas:** Mermaid (renderiza nativamente no GitHub)
- **Ferramentas opcionais testadas por quem adota:** Repomix, Ponytail, OpenSpec, Superpowers

## Build, test, lint

Sem etapa de build e sem linter: isto é um repositório template. **Existe** uma
suíte de testes, e o CI a roda em todo push.

- `baseline/hooks/tests/*.test.sh` e `baseline/scripts/tests/*.test.sh`, uma
  suíte por hook e por script, mais `tests/install-harness.test.sh` para o
  instalador. Cada um é um script bash independente: rode um direto, ou todos
  do jeito que `.github/workflows/test.yml` faz.
- O CI roda o conjunto inteiro em **ubuntu-latest e macos-latest**. Os dois
  importam: um hook que passa no macOS pode falhar no Linux por causa de
  `stat`, `date` e `awk` BSD versus GNU, e isso já aconteceu aqui.
- `baseline/scripts/check-index.sh --strict` trava o índice em `CLAUDE.md`
  contra o que de fato está no disco, e `harness-score --min-level 2` trava o
  harness em si.

Contribuições também são validadas por:

- Revisão manual contra o checklist de `CONTRIBUTING.md`
- Checagem cruzada da árvore de diretórios em `README.md` contra o filesystem real
- Verificação de que os links internos resolvem

```bash
# Verifica que os shell scripts rodam sem erro de sintaxe
bash -n baseline/hooks/*.sh
bash -n baseline/scripts/*.sh

# Verifica que o JSON é válido
python3 -m json.tool .claude/settings.json > /dev/null && echo "settings.json valid"

# Lista todos os arquivos de skill e agent para achar peças faltando
find baseline/skills -name "SKILL.md" | sort
find baseline/agents -name "*.md" | sort
```

## Estrutura

- `.claude/` configuração do Claude Code (skills, agents, hooks, rules, docs, scripts, context)
- `.github/` arquivos voltados ao GitHub (templates de issue, template de PR, instruções do Copilot)
- `docs/` documentação do projeto voltada a humanos
- `specs/` artefatos guiados por spec (uma pasta por feature; os templates `spec.md`/`plan.md`/`tasks.md` vêm com a skill `write-spec`)
- `src/example-module/` mostra o padrão de CLAUDE.md aninhado
- Raiz: config entre ferramentas (`AGENTS.md`, `CLAUDE.md`, `ECOSYSTEM.md`) e docs padrão (`README.md`, `LEARN.md`, `CONTRIBUTING.md`, `CHANGELOG.md`, `LICENSE`)

Veja o diagrama de árvore em `README.md` para o layout completo.

## Convenções

Aplicadas tanto ao conteúdo próprio do template quanto recomendadas para quem adota:

- Markdown para todos os arquivos (sem MDX, sem preprocessamento)
- Nenhum em-dash NOVO no texto, reforçado por um hook; os existentes são débito e não bloqueiam edições ao lado deles
- Um H1 por arquivo, usado como título
- Blocos de código têm tag de linguagem
- Caminhos de arquivo em código inline com backtick
- Caminhos de diretório terminam com barra (`docs/`, não `docs`)
- Datas em formato ISO (`YYYY-MM-DD`)

## Workflow de feature

Mesmo que este repo não tenha código de aplicação, adições de feature ao próprio template seguem o mesmo fluxo guiado por spec que o template ensina:

1. Discuta a mudança numa issue ou discussion
2. Opcionalmente escreva `specs/YYYY-MM-DD-<slug>/spec.md` para mudanças maiores
3. Opcionalmente separe em `plan.md` (arquitetura) e `tasks.md` (passos atômicos)
4. Implemente as mudanças, atualizando os arquivos relevantes
5. Atualize a árvore do `README.md`, o `CHANGELOG.md`, e qualquer doc afetado
6. Abra um PR referenciando a spec ou a issue

Para mudanças pequenas (correção de typo, melhoria isolada de doc), pule a spec e abra o PR direto.

## Antes de escrever código novo

Para este repo especificamente, "código novo" quase sempre significa novo markdown ou shell scripts:

- Procure arquivos semelhantes já existentes (`grep`, `find`)
- Procure padrões relacionados em `docs/patterns/` e `LEARN.md`
- Confira o diagrama de árvore em `README.md` para ver se o lugar já existe
- Prefira estender skills ou agents existentes em vez de criar paralelos
- Se for criar uma skill, subagent, hook ou rule nova, siga as seções "Adicionando..." em `CONTRIBUTING.md`

## Onde procurar

| Necessidade | Lugar |
|---|---|
| Constituição e filosofia | `docs/CONSTITUTION.md` |
| Curso guiado pela estrutura | `LEARN.md` |
| Regras de contribuição e checklists | `CONTRIBUTING.md` |
| Histórico de versões | `CHANGELOG.md` |
| Passo a passo de adoção | `docs/guides/initial-setup.md` |
| Contrato de `script/setup` / `script/test` | `docs/guides/script-setup-and-test.md` |
| Ferramentas externas recomendadas | seção "Recommended ecosystem" do `README.md` |
| Registros de decisão de arquitetura | `docs/decisions/` |

## Inegociáveis

Documentado por completo em `docs/CONSTITUTION.md`. A versão curta:

- **Agnosticismo de stack.** Nenhum arquivo pode assumir um framework, banco de dados ou fornecedor específico. Só placeholders e exemplos.
- **Compatibilidade entre ferramentas.** Todo workflow precisa ser executável por qualquer agent compatível com AGENTS.md.
- **Documentação antes de código.** Decisões estruturais são descritas, não implementadas.
- **Atribuição preservada.** Contribuições da comunidade mantêm a atribuição de autoria inline.
- **Economia de contexto.** O que carrega sempre precisa ser pequeno. O que é detalhado precisa carregar sob demanda.
- **Delegação.** A thread principal coordena; especialistas implementam. Nunca escreva código de feature na thread principal — dispare para um especialista. Regra completa (com as exceções restritas) em `baseline/rules/delegation.md`.

## Arquivos que agents não devem tocar

- `.env*` e qualquer arquivo que combine com `**/secrets/**` (bloqueado pelo hook `block-secrets.sh`)
- `node_modules/` (se algum adotante criar localmente)
- `CLAUDE.local.md`, `.claude/settings.local.json`, e `.claude/agent-memory-local/` (pessoais, no gitignore)
- `.claude/context/` (o repo map gerado, um export opcional do Repomix, e outro estado gerado, no gitignore)
- Migrações aplicadas, lockfiles, código gerado, exceto arquivos terminados em `.example` (bloqueado pelo hook `protect-critical.sh`)
- A superfície de governança — `.claude/settings.json`/`settings.local.json`, `baseline/hooks/*.sh`, `.claude/hooks/*.sh`, `baseline/rules/**`, `.claude/rules/**` — quando a edição alcança o checkout de outro repo, ou quando o alvo está no gitignore e por isso nunca apareceria num review. Editar a própria deste repo, num arquivo que aparece no diff dele, é permitido (bloqueado pelo hook `protect-harness.sh`)

## Mais contexto

- [`README.md`](./README.md) ponto de entrada para humanos, com árvore, camadas, brownfield, ecosystem
- [`LEARN.md`](./LEARN.md) curso guiado de 12 capítulos
- [`CONTRIBUTING.md`](./CONTRIBUTING.md) como contribuir sem quebrar o valor didático
- [`docs/CONSTITUTION.md`](./docs/CONSTITUTION.md) DNA do projeto
- [`docs/guides/initial-setup.md`](./docs/guides/initial-setup.md) passo a passo de adoção
- [`CHANGELOG.md`](./CHANGELOG.md) histórico de releases
