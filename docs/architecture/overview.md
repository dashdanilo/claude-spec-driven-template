# Architecture

> Revisado por último em: YYYY-MM-DD
> Substitua este template pela sua arquitetura real.

## Visão geral

Um parágrafo descrevendo o sistema em alto nível. O que ele faz, quem usa, qual é o modelo de deploy.

## Diagrama de alto nível

Diagrama ASCII ou mermaid mostrando os componentes principais e como eles se comunicam.

```
┌──────────────┐         ┌──────────────┐
│  Frontend    │────────→│  Backend API │
│              │  HTTPS  │              │
└──────────────┘         └──────┬───────┘
                                │
                ┌───────────────┼───────────────┐
                ↓               ↓               ↓
        ┌───────────┐   ┌───────────┐   ┌───────────┐
        │ Database  │   │ External  │   │ External  │
        │           │   │ Service A │   │ Service B │
        └───────────┘   └───────────┘   └───────────┘
```

## Modelo de confiança

Descreva o que executa onde e o que tem acesso a quê.

- **Client (browser):** zero segredos, só variáveis de ambiente `NEXT_PUBLIC_*`
- **Server:** tem credenciais de banco, tokens de serviços internos
- **Camada de orquestração:** tem todas as chaves de API externas
- **Serviços externos:** isolados, cada um com seus próprios rate limits

## Principais fluxos de dados

### Fluxo 1: <nome>
1. ...
2. ...

### Fluxo 2: <nome>
1. ...
2. ...

## Decisões

Decisões arquiteturais importantes vivem em `docs/decisions/` como ADRs numeradas. Exemplos:

- `0001-example.md` resume o formato

## Restrições

- Orçamento, performance, compliance ou outros limites rígidos

## Questões abertas

Decisões que ainda não foram tomadas mas vão precisar ser tomadas em breve.
