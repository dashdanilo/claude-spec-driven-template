# Três princípios

Estas são as regras por trás de como as camadas do `.claude/` (agents, skills, rules,
hooks, commands, docs, veja a tabela de camadas no próprio `README.md` do repositório
do harness) se relacionam entre si, referenciadas pelo nome em outros lugares (ex.:
o passo "Document ownership" do `orchestrate`).

1. **Um lar por tópico.** Um fato vive em exatamente uma skill/rule; as outras fazem cross-link, nunca copiam.
2. **Rule vs skill.** Uma **rule** declara *o quê* (uma linha, com escopo de caminho, sempre no contexto para aquele caminho). Uma **skill** mostra *como + por quê + exemplo* (carrega por tarefa). Convenções específicas do projeto são rules; o ensino mais rico é skills.
3. **Um dono por documento.** Quando `/orchestrate` ou `/wave` roda especialistas em paralelo, cada um escreve só suas próprias saídas — o `tasks.md` pertence ao orquestrador (ele marca as caixas), `spec.md`/`plan.md` ao autor, e um especialista nunca edita os arquivos de outra wave. ADRs são somente para acréscimo (`.claude/rules/harness/adr.md`). É isso que impede agentes paralelos de se atropelarem.
