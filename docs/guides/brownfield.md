# Adotando num codebase existente

> Movido para fora do `README.md` para manter a porta de entrada curta. Linkado a partir de lá.

## Preparando-se para brownfield

A maioria dos projetos não é construída do zero. Se você está adotando este
template num codebase que já existe, o desafio é diferente: o agente precisa
**entender o que já existe** antes de começar a criar coisas. Sem essa
disciplina, agentes tratam todo codebase como greenfield e introduzem, com
confiança, implementações paralelas de coisas que já existem.

Este template traz seis práticas para evitar isso:

**1. Skill `analyze-codebase` (setup único)**
Detecta a stack de tecnologia, amostra arquivos para inferir convenções, e
gera `docs/CONSTITUTION.md`, `docs/architecture/overview.md`,
`docs/CONVENTIONS.md`, e um repo map em `.claude/context/repo-map.md`
(sempre, independente do tamanho).

**2. Repo map (contexto panorâmico)**
Um mapa pequeno e determinístico (árvore de diretórios com contagem de
arquivos por diretório, pontos de entrada, localização de testes, o bloco de
comandos do `AGENTS.md`), gerado por `baseline/scripts/repo-map.sh`. Cresce
com a quantidade de diretórios, não com o conteúdo dos arquivos, então cabe em
repositórios reais onde um snapshot empacotado não cabe; veja
`docs/decisions/0003-repo-map-over-snapshot.md` para as medições. Sem cache,
sem verificação de obsolescência: regenerá-lo (bem abaixo de um segundo) é a
própria estratégia de frescor. Uma exportação Repomix separada e manual ainda
existe (skill `refresh-snapshot`) para entregar um arquivo único a uma
ferramenta sem acesso ao sistema de arquivos, mas é opcional e nunca lida automaticamente.

**3. Subagente `codebase-explorer` (leitura profunda)**
Arqueologia somente leitura. Gera o repo map do zero, investiga o codebase,
faz referência cruzada com os docs, retorna descobertas sem poluir o contexto principal.

**4. Skill `find-existing-first` (reusar antes de criar)**
Disparado imediatamente antes de criar qualquer arquivo novo. Busca
sinônimos, verifica padrões, reporta descobertas. Só segue para a criação se
nada adequado existir.

**5. Skill `explore` (pensar antes da spec)**
Investigação e discussão livre antes de escrever uma spec. Lê os docs e o
codebase, pesa opções, discute trade-offs. Nenhum arquivo é criado durante a exploração.

**6. Opcional: plugin Ponytail (agnóstico de projeto)**
[Ponytail](https://github.com/DietrichGebert/ponytail) é um plugin
multi-ferramenta que aplica uma escada YAGNI antes de escrever qualquer
código. Complementa as próprias skills do template.

### Fluxo de adoção num projeto existente

```
1. Clone o template dentro do projeto
2. Execute /skill analyze-codebase (gera a base de docs/)
3. Revise os docs gerados e faça commit como baseline
4. Opcional: instale o plugin Ponytail
5. Comece a usar explore + write-spec para novas features
```

O subagente `codebase-explorer` e o repo map correm silenciosamente depois
disso. Você não precisa gerenciá-los.

---
