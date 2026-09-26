# Onde essa instrução vai?

> Movido para fora do `README.md` para manter a porta de entrada curta. Linkado a partir de lá.

## Tabela de decisão: onde essa instrução vai?

| Pergunta | Lugar |
|---|---|
| Orientação entre ferramentas para qualquer agente (stack, comandos, convenções)? | `AGENTS.md` |
| Extras específicos do Claude (quais skills/agentes/hooks vêm aqui)? | `CLAUDE.md` (stub + conteúdo só do Claude) |
| Schemas compartilhados entre serviços? | `ECOSYSTEM.md` |
| DNA do projeto e princípios não negociáveis? | `docs/CONSTITUTION.md` |
| Convenções de estilo, nomenclatura, estrutura? | `docs/CONVENTIONS.md` |
| Visão geral da arquitetura do sistema? | `docs/architecture/overview.md` |
| Só se aplica dentro de uma pasta específica? | `src/<folder>/CLAUDE.md` (aninhado, conteúdo completo) |
| Se aplica ao editar um tipo de arquivo? | `baseline/rules/*.md` com `paths:` |
| Doc de referência longo, só para IA? | `baseline/docs/` |
| Docs de projeto voltados a humanos? | `docs/` |
| Processo repetível de várias etapas? | `baseline/skills/<name>/SKILL.md` |
| Especialista com perspectiva própria? | `baseline/agents/<name>.md` |
| Conhecimento que cresce com o tempo? | Subagente com o campo `memory:` |
| O que construir para esta feature? | `specs/YYYY-MM-DD-<slug>/spec.md` |
| Arquitetura e fases para ela? | `specs/YYYY-MM-DD-<slug>/plan.md` |
| Onde eu parei? Tarefas atômicas? | `specs/YYYY-MM-DD-<slug>/tasks.md` |
| Procedimento operacional (deploy, incidente)? | `docs/runbooks/` |
| Tutorial ou guia de onboarding? | `docs/guides/` |
| Pattern "como resolvemos X"? | `docs/patterns/<pattern>.md` |
| Escolha arquitetural permanente? | `docs/decisions/NNNN-*.md` |
| Docs de lib externa que mudam com frequência? | Context7 MCP, não duplicar aqui |
| Preferências pessoais? | `CLAUDE.local.md` (fora do git) |

---
