# Contribuindo

Obrigado por considerar contribuir. O valor deste template vem de ser uma referência clara e precisa. Contribuições devem preservar essa qualidade.

## Que tipos de contribuição são bem-vindos

- **Correções** de informação errada ou desatualizada
- **Melhorias** de clareza em `README.md`, `LEARN.md`, ou qualquer texto explicativo
- **Exemplos novos** que ilustram um padrão ainda não coberto
- **Relatos de bug** para inconsistências entre docs e estrutura
- **Atualizações** quando o Claude Code lança features que mudam boas práticas

## O que está fora de escopo

- Opiniões específicas de projeto amarradas a uma única stack (este template permanece agnóstico)
- Camadas ou subsistemas novos, a menos que haja um benefício didático claro
- Mudanças cosméticas que não melhoram a clareza

## Antes de abrir um pull request

1. **Leia `README.md` e `LEARN.md` do início ao fim.** Uma mudança num deles muitas vezes exige mudança no outro.
2. **Confira `CLAUDE.md` e `AGENTS.md`.** Se sua mudança afeta convenções, os dois arquivos podem precisar de atualização.
3. **Verifique a tabela de decisão em `README.md`.** Subsistemas ou arquivos novos devem caber em algum lugar nela.
4. **Garanta que os comentários da árvore de diretórios em `README.md` ainda combinam com a estrutura real.** Rode `tree` ou `find` e compare.

## Guia de estilo

- **Inglês** para toda a documentação
- **Markdown** para todos os arquivos (sem MDX, sem preprocessamento especial)
- **Nenhum em-dash** no texto
- **Um H1 por arquivo**, usado como título
- **Blocos de código têm tag de linguagem** (` ```bash `, ` ```markdown `, etc)
- **Caminhos de arquivo em código inline:** `baseline/skills/example-skill/SKILL.md`
- **Caminhos de diretório terminam com barra:** `baseline/skills/`, não `baseline/skills`
- **Datas em formato ISO:** `2026-06-21`

## Mensagens de commit

Formato Conventional Commits:

- `docs:` para mudanças de documentação
- `feat:` para exemplos novos ou subsistemas novos
- `fix:` para correções
- `chore:` para tooling, gitignore, etc

Exemplos:

```
docs: clarify when to use rules vs nested CLAUDE.md
feat: add example for hooks PostToolUse pattern
fix: correct path in subagents section of LEARN.md
```

## Checklist de validação

Antes de enviar:

- [ ] Todos os links internos funcionam (caminhos relativos)
- [ ] A árvore de diretórios em `README.md` combina com `find . -type d`
- [ ] Nenhuma suposição de stack específica de projeto (frameworks ou fornecedores específicos) vaza para os arquivos centrais
- [ ] A tabela de decisão em `README.md` inclui qualquer tipo de arquivo novo que você adicionou
- [ ] O sumário do `LEARN.md` combina com as seções dele

## Adicionando um exemplo novo

Se você adicionar um exemplo novo (rule, skill, agent, etc), siga este padrão:

1. Torne o exemplo **genérico**, mas **realista**. Evite `foo` e `bar`. Use algo como `example-skill` ou `code-reviewer`.
2. Adicione um parágrafo curto em `README.md` explicando o que o exemplo mostra
3. Referencie o exemplo em `LEARN.md` se ele ilustra um conceito
4. Garanta que o próprio arquivo de exemplo ensina: comentários inline que explicam por que a estrutura é do jeito que é

## Adicionando uma skill, subagent ou hook novo

O template traz várias skills e subagents prontos para usar. Se você adicionar novos:

- Skills vão em `baseline/skills/<name>/SKILL.md`. Descrições precisam ser condições de gatilho (`Use when...`), não documentação.
- Subagents vão em `baseline/agents/<name>.md`. Defina `tools:` de forma estreita para reduzir a superfície.
- Hooks vão em `baseline/hooks/<name>.sh` (ou outro executável). Registre em `.claude/settings.json`.
- Scripts utilitários compartilhados por vários hooks ou agents vão em `baseline/scripts/`.
- Atualize o diagrama de árvore em `README.md` para incluir o arquivo novo.

## Mudando caminhos

Caminhos aparecem em muitos lugares (READMEs, CLAUDE.md, AGENTS.md, skills, subagents, hooks). Se você renomear ou mover um arquivo:

1. Rode `grep -rn "<old-path>" .` para achar todas as referências
2. Atualize cada uma
3. Atualize os diagramas de árvore em `README.md` e qualquer README relevante
4. Teste que hooks e scripts ainda funcionam no lugar novo

## Testando shell scripts

Scripts em `baseline/scripts/` e `baseline/hooks/` devem ser testados de forma independente antes do merge:

```bash
# Simula o JSON de stdin que um hook recebe
echo '{"tool_name":"Bash","tool_input":{"command":"ls"}}' | ./baseline/hooks/block-secrets.sh
echo "Exit: $?"

# Scripts utilitários devem poder ser rodados direto
./baseline/scripts/check-snapshot.sh
```

Os dois devem ser determinísticos. Instabilidade aleatória significa que usuários têm comportamento aleatório.

CI (`.github/workflows/test.yml`) roda toda suíte de fixture `*.test.sh` dentro de `baseline/hooks/tests/` e `baseline/scripts/tests/`, mais `tests/install-harness.test.sh` e `baseline/scripts/check-index.sh --strict`, em runners de Linux e macOS.

## Perguntas

Abra uma issue com a label `question`. Para discussões maiores, abra uma discussion.

## Licença

Ao contribuir, você concorda que suas contribuições serão licenciadas sob a Licença MIT.
