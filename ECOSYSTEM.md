# ECOSYSTEM.md

> Schemas e contratos compartilhados entre as superfícies do sistema. Substitua os exemplos abaixo pelas suas entidades reais.

Fonte de verdade para tipos que aparecem em mais de um lugar: código do framework, camada de orquestração, integrações externas, payloads de evento.

Mantenha este arquivo **denso e factual**. Sem histórico, sem justificativa. Só contratos.

## Entidades

### ExampleEntity

A forma canônica, espelhada no banco de dados, nos payloads de API e em serviços externos.

| Campo | Tipo | Origem | Notas |
|---|---|---|---|
| `id` | uuid v4 | gerado pelo servidor | nunca exposto ao client antes do submit |
| `name` | string | input do usuário | obrigatório, mínimo de 2 caracteres |
| `email` | string | input do usuário | validado, normalizado para minúsculas |
| `created_at` | iso datetime | servidor | UTC |

Adicione ou remova campos para combinar com suas entidades reais.

## Enums

Defina enums aqui para que todas as superfícies concordem:

- `status`: `pending` | `active` | `archived`
- `tier`: `free` | `pro` | `enterprise`

## Payloads de evento

Formato dos eventos que cruzam fronteiras de serviço:

```jsonc
{
  "type": "example.created",
  "id": "uuid",
  "entity": { /* ExampleEntity */ },
  "timestamp": "iso",
  "version": 1
}
```

## Convenções de nomenclatura

- snake_case nos payloads JSON (compatível com a maioria dos serviços externos)
- camelCase nos internals de TypeScript
- Conversão na fronteira: normalmente em `src/lib/<domain>/schema.ts`

## Contratos de webhook

- Entrada: `POST /api/webhook/<source>` com verificação de assinatura HMAC
- Saída: assinatura HMAC correspondente, retry com backoff exponencial

## Versionamento

Qualquer mudança num schema deste arquivo é uma breaking change. Suba a versão, atualize todos os consumidores, e migre. Não mude em silêncio.
