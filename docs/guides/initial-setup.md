# Setup inicial: adotando este template

Passo a passo para usar o template num projeto novo ou existente. Leia isto
uma vez antes de começar.

## Pré-requisitos

- Git (qualquer versão recente), Bash, e Python 3 (padrão em qualquer máquina de dev; o repo map e as próprias verificações do harness usam só isso)
- Node.js 20+, opcional: só necessário se você usar a skill manual `refresh-snapshot` (Repomix v1.16+ exige Node 20; Node mais antigo produz uma exportação vazia)
- Ao menos um agente de codificação de IA instalado. Claude Code é recomendado, mas o template funciona com Codex, Cursor, Copilot e Gemini também.

## Caminho 1: Projeto novo (greenfield)

Você está começando um projeto do zero.

### 1. Crie o repositório a partir do template

Se estiver navegando no GitHub:

1. Clique em "Use this template" > "Create a new repository"
2. Dê um nome, escolha a visibilidade, clique em Create

Se estiver clonando localmente:

```bash
git clone https://github.com/dashdanilo/claude-spec-driven-template my-project
cd my-project
rm -rf .git
git init
```

### 2. Personalize o AGENTS.md (fonte da verdade)

Abra `AGENTS.md`. Substitua:

- O nome do projeto no topo
- A seção de stack de tecnologia pela sua stack real
- Os comandos de build/test/lint pelos comandos reais
- A seção de estrutura pelo layout real de pastas
- As convenções para casar com as preferências do seu time

Este é o arquivo que todo agente de IA vai ler. Dedique tempo a isso.

### 3. Personalize o CLAUDE.md (stub)

Abra `CLAUDE.md`. Só atualize o nome do projeto no topo. O resto é
auto-configurado com base nas skills, subagentes e hooks em `.claude/`.

### 4. Atualize o README.md

Substitua o nome do projeto e a descrição. Mantenha as seções estruturais
(elas explicam o design do template e são úteis para contribuidores).

### 5. Limpe os exemplos

Depois de entender os padrões:

- Delete ou substitua `src/example-module/CLAUDE.md`
- Renomeie `.claude/skills/example-skill/` para sua primeira skill real (ou delete)
- Renomeie `.claude/rules/example-rule.md` para sua primeira regra real (ou delete)
- Delete `docs/decisions/0001-example.md` (substitua pela sua primeira ADR)
- Delete `.claude/docs/libs/example-lib.md` quando adicionar sua primeira doc de lib real
- Renomeie `docs/CONSTITUTION.md.example` para `docs/CONSTITUTION.md` e preencha

### 6. Opcional: adicione `script/setup` e `script/test`

Se seu time quer um comando que leve um clone (ou worktree) a "pronto para
trabalhar", e um comando que seja o gate de verificação, adicione
`script/setup` e `script/test` executáveis na raiz do repositório. O harness
só *chama* esses scripts quando existem (o `spec-worktree` executa
`script/setup` depois de criar um worktree, e o `verify-before-done` usa
`script/test` como gate em vez de adivinhar comandos). Ele não os gera para
você, e um repositório sem eles não perde nada: o passo é um no-op. Veja
[`docs/guides/script-setup-and-test.md`](./script-setup-and-test.md).

### 7. Faça commit da baseline

```bash
git add .
git commit -m "chore: adopt claude-spec-driven-template as v0.1 baseline"
```

### 8. Comece a usar

Para sua primeira feature:

```
/skill explore                        # discuta o que construir
/skill write-spec my-first-feature    # cria specs/2026-07-04-my-first-feature/ com spec.md preenchido e plan.md, tasks.md montados
```

Depois preencha `plan.md` (arquitetura, tecnologia, fases) e `tasks.md`
(checkboxes atômicos de TDD), e comece a construir.

---

## Caminho 2: Projeto existente (brownfield)

Você já tem código e quer adotar este template.

### 1. Instale o scaffolding

Use o instalador. Execute-o de dentro do seu repositório (ele busca o
template atualizado):

```bash
cd /path/to/your-project
curl -fsSL https://raw.githubusercontent.com/dashdanilo/claude-spec-driven-template/main/install.sh | bash
```

Ou, a partir de um clone local do template, aponte para o seu repositório:

```bash
./install.sh --to /path/to/your-project
```

O instalador copia o scaffolding do agente (`.claude/`, `docs/`, `specs/`,
`AGENTS.md`, `CLAUDE.md`, `ECOSYSTEM.md`, `.claudeignore`, `.github/`,
`CLAUDE.local.md.example`), e:

- **Nunca sobrescreve** arquivos que já existem no seu repositório (pula e
  avisa; use `--force` para forçar). Seu `README.md`, `.gitignore`, e
  qualquer arquivo `docs/` existente estão seguros.
- **Mescla** as entradas necessárias no seu `.gitignore` (adiciona o que estiver faltando).
- Copia só arquivos do template rastreados pelo git (sem lixo local/gerado) e torna os hooks executáveis.

Pré-visualize sem escrever nada usando `--dry-run`.

### 2. Execute o `analyze-codebase` para a baseline

Este é o passo crítico para brownfield. Abra o Claude Code e execute:

```
/skill analyze-codebase
```

A skill vai:

- Detectar sua stack de tecnologia a partir de `package.json`, `tsconfig.json`, etc
- Amostrar arquivos representativos para inferir convenções
- Gerar `docs/CONSTITUTION.md`, `docs/CONVENTIONS.md`, `docs/architecture/overview.md`
- Gerar um repo map em `.claude/context/repo-map.md` (sempre, independente do tamanho do projeto)
- Atualizar `AGENTS.md` e `CLAUDE.md` com a stack detectada

### 3. Revise os docs gerados

Procure por marcadores `TODO` nos arquivos gerados. É onde a análise ficou
incerta. Preencha-os com seu conhecimento.

Revise também:

- A stack de tecnologia em `AGENTS.md` (pode precisar de ajuste)
- As convenções em `docs/CONVENTIONS.md` (são de fato as convenções do seu time?)
- A visão de arquitetura em `docs/architecture/overview.md` (o diagrama reflete a realidade?)

### 4. Faça commit da baseline

```bash
git add .
git commit -m "chore: adopt claude-spec-driven-template with generated baseline"
```

### 5. Opcional: adicione `script/setup` e `script/test`

Se seu time quer um comando que leve um clone (ou worktree) a "pronto para
trabalhar", e um comando que seja o gate de verificação, adicione
`script/setup` e `script/test` executáveis na raiz do repositório. O harness
só *chama* esses scripts quando existem (o `spec-worktree` executa
`script/setup` depois de criar um worktree, e o `verify-before-done` usa
`script/test` como gate em vez de adivinhar comandos). Ele não os gera para
você, e um repositório sem eles não perde nada: o passo é um no-op. Veja
[`docs/guides/script-setup-and-test.md`](./script-setup-and-test.md).

### 6. Opcional: instale plugins recomendados

- [Ponytail](https://github.com/DietrichGebert/ponytail) para reforço de YAGNI entre ferramentas
- [Superpowers](https://github.com/obra/superpowers) para fluxo guiado por spec forçado (só Claude)
- [OpenSpec](https://github.com/Fission-AI/OpenSpec) para fluxo de spec entre ferramentas

### 7. Primeira feature usando o template

```
/skill explore                    # discuta o que construir
/skill find-existing-first        # verifique se código semelhante já existe
/skill write-spec <slug>          # crie a spec
```

---

## Mantendo o template com o tempo

### O repo map, e quando você tocaria no Repomix

O repo map regenera do zero a cada vez que o `codebase-explorer` executa. Não
há nada para atualizar e nada para pensar sobre isso.

A exportação Repomix é uma coisa diferente e separada: manual, opcional, e só
útil se você precisar de um dump de arquivo único do codebase para uma
ferramenta que não pode ler o sistema de arquivos por conta própria. A
maioria das sessões nunca precisa dela:

```
/skill refresh-snapshot
```

Veja `docs/decisions/0003-repo-map-over-snapshot.md` para entender por que
agora são dois mecanismos diferentes em vez de um.

### Quando adicionar um novo subagente

Quando você se pegar invocando um padrão específico repetidamente ("verifique
o tratamento de autenticação aqui", "faça profiling deste caminho de
código"). Crie um subagente com um papel restrito e uma descrição de gatilho.

### Quando adicionar uma nova ADR

Quando alguém perguntar "por que fizemos X?" mais de duas vezes. Transforme a
resposta numa ADR em `docs/decisions/`.

### Quando atualizar `docs/CONVENTIONS.md`

Quando você notar comentários de code review repetindo o mesmo feedback. Isso
é uma convenção que vale documentar.

### Quando atualizar `AGENTS.md`

Quando a stack mudar (upgrade de framework, novo serviço externo, troca de
dependência importante). Atualize uma vez, todos os agentes veem a mudança.

---

## Troubleshooting

### O hook de SessionStart mostra avisos que eu não quero

Edite `.claude/context/config.json` para ajustar os limiares, ou desative o
hook removendo-o de `.claude/settings.json`.

### `refresh-snapshot` parece travar

Só relevante se você estiver usando a exportação Repomix manual (o próprio
`analyze-codebase` não executa mais o Repomix de forma alguma, então nunca
deveria travar por causa disso). O passo do Repomix dentro de
`refresh-snapshot` pode levar de 30 a 60 segundos em repositórios grandes. Se
ainda estiver rodando depois de 2 minutos, cancele e adicione um
`.repomixignore` para reduzir o escopo.

### O Claude parece não saber sobre as skills

Verifique:

- O arquivo da skill existe em `.claude/skills/<name>/SKILL.md`
- O frontmatter tem `name` e `description` válidos
- A descrição começa com uma condição de gatilho (`Use when...`)

Descrições são o gatilho de auto-invocação, não documentação.

### Preocupações entre ferramentas

- Codex, Cursor e Gemini leem `AGENTS.md` nativamente (ou via configuração)
- Copilot lê `.github/copilot-instructions.md`
- Só o Claude Code lê `.claude/`, as outras ferramentas o ignoram

Atualize `AGENTS.md` para mudanças entre ferramentas. Atualize `CLAUDE.md` só
para coisas específicas do Claude.
