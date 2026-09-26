# Constitution

O DNA deste projeto. O que ele é, o que ele não é, e os princípios não negociáveis que orientam as decisões.

Mantenha este arquivo denso e estável. Ele deve mudar raramente. Quando mudar, isso é um sinal de que algo fundamental mudou.

## O que este projeto é

`claude-spec-driven-template` é um repositório-template para estruturar projetos habilitados por IA em torno de desenvolvimento guiado por spec (spec-driven development). Ele fornece uma estrutura de pastas reutilizável, configuração de agentes, skills, subagentes, hooks e padrões de fluxo de trabalho que funcionam com Claude Code, GitHub Copilot e outras ferramentas compatíveis com AGENTS.md.

O template é agnóstico de stack: não assume nenhum framework, banco de dados ou linguagem específica. Ele é entregue como uma fundação estrutural e de documentação, para ser adotada, adaptada e usada como base de projetos reais.

## O que este projeto NÃO é

Limites explícitos. Coisas que este template nunca deve se tornar ou tentar ser:

- **Não é uma aplicação.** Não há runtime, não há servidor, não há UI. Apenas documentação, configuração e scripts shell.
- **Não tem opinião sobre stack de tecnologia.** Sem preferência entre Next.js e Remix, Postgres e MySQL, Tailwind e CSS Modules. Quem adota traz sua própria stack.
- **Não está atrelado a uma única ferramenta de IA.** O template trata AGENTS.md como fonte da verdade. Claude Code, Copilot, Codex, Cursor e Gemini devem funcionar de forma equivalente ao usar este template.
- **Não é um framework de gestão de projetos.** Ele fornece estrutura guiada por spec, mas nenhum rastreamento de tickets, nenhum relatório, nenhum dashboard.
- **Não é um plugin.** É um repositório-template, feito para ser copiado. Não é instalado, não gera dependência.
- **Não é um curso.** LEARN.md é um curso guiado pela estrutura, mas o template não tem o objetivo de ensinar programação, testes ou gestão de produto do zero.

## Princípios não negociáveis

Estes princípios têm prioridade sobre conveniência. Se uma mudança proposta viola um deles, a mudança é rejeitada, independentemente de quão conveniente ela seria.

1. **Agnosticismo de stack.** Nenhum arquivo do template pode assumir um framework, banco de dados ou fornecedor específico. Somente placeholders e exemplos.
2. **Compatibilidade entre ferramentas.** Todo fluxo de trabalho documentado precisa ser executável por qualquer agente compatível com AGENTS.md, não só pelo Claude Code.
3. **Documentação acima de código.** Decisões estruturais são documentadas em `docs/` e `LEARN.md`. Comportamentos complexos são descritos, não implementados.
4. **Atribuição preservada.** Contribuições da comunidade mantêm a atribuição de autoria inline, permanentemente.
5. **Economia de contexto.** O que carrega sempre precisa ser pequeno. O que é detalhado precisa carregar sob demanda. Este princípio orienta toda a estratificação do subsistema.

## Vocabulário do domínio

Termos específicos deste template e seu significado exato:

- **Template:** o repositório que você está lendo agora. Feito para ser clonado ou usado pelo botão "Use this template" do GitHub.
- **Adotante (adopter):** um desenvolvedor ou time que usa o template no próprio projeto.
- **Adoção:** o ato de aplicar o template a um projeto existente (brownfield) ou novo (greenfield).
- **CLAUDE.md aninhado:** um arquivo `CLAUDE.md` dentro de `src/<pasta>` que adiciona convenções específicas daquela pasta.
- **Stub:** um arquivo pequeno cujo propósito é apontar para outro arquivo onde está o conteúdo real. `CLAUDE.md` e `.github/copilot-instructions.md` na raiz são stubs que apontam para `AGENTS.md`.
- **Fonte da verdade:** o arquivo que é dono de uma informação. Para contexto do projeto, é `AGENTS.md`. Para uma feature, é `specs/<slug>/spec.md`.
- **Too-large, fresh, stale-mild, stale-major:** os estados classificados por `.claude/scripts/check-snapshot.sh` para a exportação Repomix opcional e manual. Too-large é verificado primeiro e independe dos outros três (ver ADR 0003).
- **Repo map:** o artefato determinístico e sempre regerado de árvore de diretórios mais metadados (`baseline/scripts/repo-map.sh` → `.claude/context/repo-map.md`) que substituiu o snapshot Repomix como contexto panorâmico. Ver `docs/decisions/0003-repo-map-over-snapshot.md`.

## Stack de tecnologia (do template em si, não de quem adota)

- **Formato de documentação:** Markdown
- **Scripts shell:** Bash (compatível com POSIX quando possível)
- **Formato de configuração:** JSON (para `.claude/settings.json`)
- **Formato de diagrama:** Mermaid (renderizado nativamente no GitHub)
- **Ferramentas de IA testadas:** Claude Code, GitHub Copilot

## Restrições e não objetivos

Limites rígidos que orientam o design:

- **Orçamento:** custo recorrente zero. Todas as ferramentas necessárias têm camadas gratuitas.
- **Dependências de runtime:** nenhuma. Quem adota pode instalar ferramentas opcionais (Repomix, Ponytail, OpenSpec, Superpowers), mas o template funciona sem elas.
- **Compliance:** nenhuma suposição sobre GDPR, LGPD, HIPAA ou SOC2. Quem adota traz suas próprias exigências de compliance.
- **Não objetivos explícitos:**
  - Não evoluir para uma ferramenta CLI
  - Não evoluir para um pacote npm
  - Não exigir configuração de CI para ser útil
  - Não exigir nenhuma conta, chave de API ou assinatura SaaS

## Onde vivem as fontes da verdade

- Contexto de projeto entre ferramentas: `AGENTS.md`
- Contexto específico do Claude: `CLAUDE.md`
- Contexto específico do Copilot: `.github/copilot-instructions.md`
- Specs de features: `specs/YYYY-MM-DD-<slug>/`
- Decisões de arquitetura: `docs/decisions/`
- Runbooks: `docs/runbooks/`
- Guias e tutoriais: `docs/guides/`
- Exemplos vivos de soluções: `docs/patterns/`
- Conhecimento só para IA: `.claude/docs/`
- Histórico de mudanças: `CHANGELOG.md`

## Change log

Atualizações a este arquivo são raras. Quando acontecerem, registre-as aqui:

- 2026-07-04 - Constitution inicial escrita junto com o lançamento v0.1.0.
