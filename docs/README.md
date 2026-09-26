# docs/

Documentação legível por humanos do projeto. Lida por desenvolvedores, revisores e agentes de IA igualmente.

## Layout

```
docs/
├── CONSTITUTION.md           # DNA do projeto: o que é, princípios, limites (opcional)
├── CONVENTIONS.md            # Convenções de nomenclatura, imports, estrutura (opcional)
├── architecture/             # Design do sistema
│   └── overview.md           # Arquitetura de alto nível, modelo de confiança, fluxos de dados
├── decisions/                # ADRs (imutáveis, numeradas)
│   ├── README.md
│   └── NNNN-title.md
├── runbooks/                 # Procedimentos operacionais
│   ├── README.md
│   ├── deploy.md
│   ├── rollback.md
│   └── incident-response.md
├── guides/                   # Onboarding, how-tos, tutoriais
│   ├── README.md
│   ├── getting-started.md
│   └── testing.md
└── patterns/                 # "Como resolvemos X" - exemplos vivos
    ├── README.md
    └── <pattern-name>.md
```

## O que vai aqui vs `.claude/docs/`

Use esta decisão:

- **Humanos precisam ler? → `docs/`**
- **Só agentes precisam? → `.claude/docs/`**

Concretamente:

| Conteúdo | Localização |
|---|---|
| Visão de arquitetura, ADRs, runbooks, guias | `docs/` |
| Padrões e decisões de design que valem ser ensinados | `docs/patterns/` |
| Constitution / descrição do estado atual | `docs/CONSTITUTION.md` |
| Convenções de estilo e nomenclatura | `docs/CONVENTIONS.md` |
| Como agentes devem usar uma lib externa específica neste projeto | `.claude/docs/libs/` |
| Docs de fluxo de trabalho específicas para IA (Superpowers, notas sobre spec-driven) | `.claude/docs/` |

## Os docs gerados

Alguns arquivos aqui são gerados pela skill `analyze-codebase` ao adotar o template num projeto existente:

- `CONSTITUTION.md` - inferido a partir da estrutura do projeto e docs existentes
- `CONVENTIONS.md` - inferido amostrando arquivos representativos
- `architecture/overview.md` - inferido a partir da estrutura e configs
- `patterns/README.md` - montado como um scaffold vazio

Arquivos gerados sempre têm marcadores `TODO` onde a análise ficou incerta. Espera-se revisão humana.

## Os docs escritos à mão

Alguns arquivos só existem quando um humano os escreve:

- ADRs em `decisions/` - sempre escritas à mão, imutáveis depois de aceitas
- `runbooks/` - escritos à mão por quem opera o sistema
- `guides/` - escritos à mão para onboarding e tutoriais
- `patterns/*.md` individuais - um por problema resolvido que vale ser ensinado

## Referenciado por agentes

Os agentes de IA deste template leem `docs/` extensivamente:

- `codebase-explorer` lê `CONSTITUTION.md`, `architecture/overview.md`, `CONVENTIONS.md` e `patterns/`
- a skill `explore` lê os mesmos antes de propor
- `write-spec` linka para eles em toda spec nova
- `code-reviewer` verifica mudanças contra `CONVENTIONS.md`

Mantenha-os precisos e atualizados.

## `reference/`

Contexto retirado do `README.md` para a porta de entrada continuar curta:

- [`layers.md`](./reference/layers.md): as quatro camadas de instrução e para que serve cada uma, incluindo o que os hooks fazem
- [`spec-driven.md`](./reference/spec-driven.md): como `spec.md` / `plan.md` / `tasks.md` se relacionam
- [`where-does-it-go.md`](./reference/where-does-it-go.md): tabela de decisão para posicionar uma instrução
- [`ecosystem.md`](./reference/ecosystem.md): ferramentas que combinam bem com este harness
