# Ecossistema recomendado

> Movido para fora do `README.md` para manter a porta de entrada curta. Linkado a partir de lá.

## Ecossistema recomendado

O template funciona de forma independente. Ele também se combina bem com um
pequeno conjunto de ferramentas externas que resolvem problemas ortogonais.
Nenhuma é obrigatória, mas todas merecem seu lugar.

### Plugins para Claude Code

**[Ponytail](https://github.com/DietrichGebert/ponytail)**: plugin
multi-ferramenta que aplica uma escada YAGNI antes de escrever qualquer
código. Complementa o `find-existing-first`. Instalação:
```
/plugin marketplace add DietrichGebert/ponytail
/plugin install ponytail@ponytail
```

**[Superpowers](https://github.com/obra/superpowers)**: plugin exclusivo do
Claude com fluxo forçado de brainstorm → spec → plan → TDD. Traz skills como
`brainstorming`, `writing-plans`, `subagent-driven-development`,
`finishing-a-development-branch`. Compatível com o layout `specs/` deste
template. Instalação:
```
/plugin install superpowers@claude-plugins-official
```

### Frameworks de spec entre ferramentas

**[OpenSpec](https://github.com/Fission-AI/OpenSpec)**: CLI mais skills
abrangendo mais de 30 ferramentas de codificação de IA. Traz `/opsx:explore`
para investigação pré-spec e delta specs desenhadas para brownfield. Configure
para escrever na pasta `specs/` deste template em vez de
`openspec/changes/`. Instalação:
```
npm install -g @fission-ai/openspec@latest
cd your-project && openspec init
```

### Ferramentas de contexto

**[Repomix](https://github.com/yamadashy/repomix)**: empacota o codebase
inteiro num único arquivo. Não é o mecanismo de contexto panorâmico deste
harness (esse é o repo map embutido, ver
`docs/decisions/0003-repo-map-over-snapshot.md`, gerado por
`baseline/scripts/repo-map.sh` sem dependência externa); conectado só à skill
manual e opcional `refresh-snapshot`, para entregar um arquivo único a
alguma outra ferramenta sem acesso ao sistema de arquivos. Instalação:
```
npm install -g repomix
# ou use via npx
```

**[Context7 MCP](https://github.com/upstash/context7)**: servidor MCP que
entrega documentação de biblioteca versionada e sempre atualizada. Use em vez
de duplicar docs oficiais em `baseline/docs/libs/`. Aponte para ele na sua
configuração do Claude Code uma vez, os agentes o consultam sob demanda.

### Escolhendo seu tooling guiado por spec

Três configurações sensatas dependendo do time:

| Configuração | Ferramentas | Melhor para |
|---|---|---|
| Só Claude, opinativa | Template + Superpowers + Ponytail | Dev solo ou time todo-Claude querendo o máximo de rigor |
| Entre ferramentas, flexível | Template + OpenSpec + Ponytail | Time com Cursor/Codex/Gemini junto com o Claude |
| Só o template | Apenas as skills próprias do template | Testando antes de adicionar qualquer outra coisa |

As três compartilham o mesmo layout de pasta `specs/YYYY-MM-DD-<slug>/`,
então alternar entre elas no meio do projeto não invalida specs existentes.

---
