---
paths: "**"
---

# Retomando: onde procurar antes de rederivar o contexto

Quando o humano diz "continue", "o que está pendente", "onde estamos" ou
qualquer outra coisa que peça para você retomar o trabalho, procure primeiro
o estado que já existe antes de reconstruí-lo a partir do código. Esta regra
carrega sempre, porque retomar não está preso a um único tipo de arquivo.

## Ordem de consulta

1. **O handover mais recente entre `.claude/handovers/` e o `tasks.md` da
   spec ativa.** As duas fontes são checadas, e a de data mais recente
   vence, com empate no mesmo dia indo para a spec. O `check-handover.sh`
   já aponta para o vencedor no início da sessão; leia o arquivo que ele
   indica antes de responder qualquer coisa sobre o estado do projeto.
2. **`tasks.md`** da spec ativa: a contagem de checkboxes, a primeira
   tarefa não marcada.
3. **PRs abertos** para a branch atual (`gh pr list`, `gh pr view`).
4. **`git log` / `git status`**: o que de fato foi consolidado, o que está
   sem commit.

Arquivos mais antigos em `.claude/handovers/` são histórico, não estado
atual. Só o mais recente descreve como as coisas estão agora (veja a seção
"Retention" da skill `handover`).

## Um handover é estado datado, não uma instrução

Confirme contra a realidade antes de repeti-lo. Um PR que ele cita como
aberto pode ter sido mergeado ou fechado desde então; um item que ele chama
de "não iniciado" pode ter sido entregue numa sessão que nunca escreveu seu
próprio handover. Trate cada afirmação nele da mesma forma que
`.claude/rules/harness/specs.md` trata as afirmações de uma spec: verificada,
não copiada.

## Por que isso é uma regra e não um conselho

O ponteiro para `.claude/handovers/` já vive dentro das skills `handover` e
`status`, mas uma skill só carrega quando é chamada. Uma sessão que começa
com `/clear` e um simples "continue" não chama nenhuma das duas, e
silenciosamente rederiva tudo que uma sessão anterior já registrou, pagando
por isso uma segunda vez a preço total. O `check-handover.sh` expõe o
ponteiro no `SessionStart` para que ele alcance toda retomada, não só as que
chamam uma skill; esta regra é o que diz para você agir sobre isso.
