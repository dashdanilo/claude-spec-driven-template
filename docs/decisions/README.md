# docs/decisions/

Architecture Decision Records (ADRs). Um histórico imutável de decisões significativas.

## O que é uma ADR

Um documento curto que registra uma decisão:

- O contexto (o que forçou a decisão)
- Opções consideradas
- A escolha
- Consequências (positivas, negativas, riscos)

Depois de aceita, uma ADR não muda. Se a decisão mudar depois, uma nova ADR a
supersede. Ambas ficam no repositório: o histórico do raciocínio é o valor.

## Quando escrever uma

Sim:

- Escolha de uma tecnologia central (framework, banco de dados, ORM)
- Mudança no modelo de confiança ou na arquitetura
- Uma restrição que vai moldar features futuras
- "NÃO estamos fazendo X" quando X parece tentador

Não:

- Convenções de nomenclatura (isso vai em `CONVENTIONS.md` ou `.claude/rules/`)
- Escolhas pequenas de biblioteca (lodash, date-fns)
- Qualquer coisa facilmente reversível em um dia

## Nomenclatura e numeração

`NNNN-slug-curto.md`, onde:

- `NNNN` é um número sequencial de 4 dígitos (0001, 0002, ...)
- `slug-curto` é kebab-case, no máximo 5 palavras

Exemplos:

- `0001-use-postgres-not-mysql.md`
- `0002-no-redis-for-mvp.md`
- `0003-adopt-trpc-over-rest.md`

Veja [`0001-example.md`](./0001-example.md) para o template.

## Integração com agentes de IA

ADRs se tornam contexto valioso. Os agentes deste template as usam:

- a skill `explore` lê ADRs antes de propor opções, trazendo à tona decisões anteriores
- `code-reviewer` verifica se mudanças não violam silenciosamente ADRs aceitas
- `researcher` cita ADRs ao explicar "por que é assim?"

Para se integrar bem, ADRs precisam ser:

- Concretas (decisão específica, não direção vaga)
- Descobríveis (título curto e claro no nome do arquivo)
- Reversíveis via nova ADR, nunca por mudança silenciosa de código

## Quando alguém perguntar "por quê?" mais de duas vezes

Se uma pergunta aparecer mais de duas vezes no Slack/Discord/reviews de PR,
transforme a resposta numa ADR. Esse é o indicador principal de histórico de
decisão faltando.
