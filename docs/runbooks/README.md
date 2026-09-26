# docs/runbooks/

Procedimentos passo a passo para tarefas operacionais. Quando você está de
plantão às 3 da manhã, você segue um runbook, não um diagrama de arquitetura.

## O que é um runbook

Uma checklist para uma tarefa operacional específica:

- Fazer deploy em produção
- Fazer rollback de um deploy que falhou
- Rotacionar credenciais
- Responder a um tipo de incidente
- Integrar uma nova integração

A regra: alguém sem familiaridade com o sistema deveria conseguir executar o
runbook seguindo-o literalmente. Se precisar pensar, o runbook está incompleto.

## Formato

```markdown
# <Nome da tarefa>

**Quando usar:** <a situação específica>
**Tempo estimado:** <estimativa realista>
**Requer:** <acesso, ferramentas, credenciais>

## Verificações prévias

1. Confirme que você tem <acesso>
2. Avise o #ops no Slack
3. Verifique se não há incidentes ativos

## Procedimento

1. Passo um
   ```bash
   comando exato
   ```
   Saída esperada: <o que você deveria ver>

2. Passo dois
   ...

## Verificação

Como confirmar que a tarefa teve sucesso.

## Rollback

Se o passo N falhar, faça isto para revertê-lo.

## Falhas comuns

- Sintoma → causa → correção
- Sintoma → causa → correção

## Contatos

Quem chamar se este runbook falhar.
```

## Runbooks sugeridos para criar

- `deploy.md` - deploy em produção
- `rollback.md` - desfazer um deploy
- `incident-response.md` - os primeiros 30 minutos quando algo quebra
- `credential-rotation.md` - rotacionar chaves de API
- `db-migration.md` - executar uma migration de schema com segurança

## Higiene de runbook

- Teste todo runbook ao menos uma vez por trimestre (dry run em staging)
- Atualize imediatamente depois que um incidente revelar uma lacuna
- Registre a data da última execução verificada no topo

## Integração com agentes de IA

Agentes leem runbooks quando o usuário faz perguntas operacionais ("como eu
faço deploy?", "e se o deploy falhar?"). Mantenha-os fáceis de escanear: um
muro de texto é inútil às 3 da manhã.
