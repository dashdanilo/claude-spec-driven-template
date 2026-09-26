---
paths: "**/*.{tsx,jsx,ts,js}"
---

# Regra de exemplo (renomeie este arquivo)

> Uma regra é uma convenção com escopo de caminho. O glob `paths:` no frontmatter determina quando esta regra carrega automaticamente.
> Sem `paths:`, a regra carrega sempre (tornando-se um CLAUDE.md escondido). Sempre dê escopo às regras.

Isto é o que uma regra parece. Substitua o conteúdo pelas suas convenções reais.

## Convenções de exemplo

- Só exports nomeados, sem export default
- Padrões funcionais em vez de baseados em classe
- Async/await em vez de cadeias .then()
- Imports de tipo separados: `import type { Foo } from './foo'`
- Evite `any`. Use `unknown` e restrinja o tipo.

## Para que servem as regras

- Convenções com escopo de caminho que se aplicam a vários arquivos de um tipo
- Regras rígidas que um code-reviewer deve aplicar
- Declarações curtas e factuais (não explicações)

## Para que as regras NÃO servem

- Documentação longa (use `.claude/docs/`)
- Convenções específicas de pasta (use `src/<folder>/CLAUDE.md` aninhado)
- Fluxos de trabalho reutilizáveis (use `.claude/skills/`)
- Raciocínio sobre o porquê (decisões vão em `docs/decisions/`)

## Mantenha curto

Uma boa regra tem 20-50 linhas. Se a sua for mais longa, ela pode estar escondendo três regras num arquivo só, ou pode ser documentação que pertence a `.claude/docs/`.
