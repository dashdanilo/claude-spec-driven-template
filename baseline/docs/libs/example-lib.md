# Example Lib (renomeie este arquivo)

> Última revisão: YYYY-MM-DD
> Versão da lib: X.Y.Z
> Docs oficiais: <url>

> Isto é um template. Renomeie o arquivo para a lib real (ex.: o nome do serviço ou pacote) e substitua o conteúdo.

## Por que a usamos

Uma linha. O papel que essa lib desempenha no sistema.

## Como autenticamos

- Nomes de variáveis de ambiente
- Local de armazenamento do token
- Cronograma de rotação do token
- Quem tem acesso

## Endpoints / features que usamos

| Método | Endpoint ou feature | Usado para |
|---|---|---|
| POST | `/v1/example` | operação de exemplo |
| GET | `/v1/example/:id` | busca de exemplo |

## Configuração customizada

Configuração específica deste projeto, não os padrões da lib:

- ...

## Pegadinhas

Coisas que já pegamos em produção e não são óbvias pelos docs:

- **Comportamento de paginação:** a API retorna 100 itens por página por padrão
- **Rate limits:** 50 req/min no tier gratuito, escala com o tier
- **Idempotência:** obrigatória em operações de escrita para tratar retries com segurança
- **Timezone:** todos os timestamps são UTC, é preciso converter na borda

## Troubleshooting

| Sintoma | Causa | Correção |
|---|---|---|
| 401 Unauthorized | Token expirado | Rode o refresh do token |
| 429 Rate Limit | Cota excedida | Backoff exponencial, considere upgrade |
| Timeout | Rede ou backend lento | Retry com timeout maior |

## O que NÃO fazer

- Não chame esta lib direto do frontend
- Não logue payloads completos (podem conter PII)
- Não fixe IDs no código que deveriam ser configuráveis

## Quando atualizar este documento

- Bumps de versão da lib (até patches às vezes mudam comportamento)
- Nova pegadinha descoberta durante debugging
- Novo endpoint ou feature adicionado ao uso do projeto

Passe os olhos nos docs oficiais a cada trimestre em busca de breaking changes.
