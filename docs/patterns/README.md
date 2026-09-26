# docs/patterns/

Exemplos vivos de "como resolvemos X neste projeto". Um pattern é um trecho
pequeno e real mostrando como um problema específico foi resolvido aqui, para
que soluções futuras possam seguir a mesma forma.

## Por que patterns são melhores que prosa

Três parágrafos descrevendo "usamos padrões funcionais e preferimos
composição em vez de herança" ensinam quase nada. Um trecho de 15 linhas
mostrando uma composição real neste codebase ensina tudo.

Patterns são a documentação com maior sinal por token que você pode
escrever. Agentes se beneficiam especialmente deles: mostram convenções em
ação, não em abstrato.

## Formato de um pattern

Cada pattern é um arquivo markdown curto:

```markdown
# <Nome do pattern>

**Quando usar:** <a situação que este pattern resolve>
**Onde no codebase:** <caminhos de exemplo>
**Relacionado:** <outros patterns ou docs>

## Problema

Um parágrafo. Que situação dispara este pattern.

## Solução

O pattern em si, mostrado como um trecho de código real (ou realista).

`​``ts
// Código real demonstrando o pattern
`​``

## Quando NÃO usar isto

Casos em que este pattern é a escolha errada.

## Alternativas consideradas

Brevemente, outras abordagens e por que esta venceu.

## Referências

Arquivos no codebase que seguem este pattern:

- `src/path/file1.ts`
- `src/path/file2.ts`
```

## Tópicos de pattern sugeridos

Só adicione patterns quando você tiver um exemplo real e resolvido. Alguns candidatos comuns:

- Tratamento de erro em código de servidor
- Estado de carregamento na UI
- Fluxo de validação de formulário
- Wrapper de requisição de API
- Verificação de feature flag
- Lógica de retry
- Ponto de chamada de logging estruturado
- Estratégia de cache para um tipo de dado específico

## Anti-patterns

Você também pode documentar anti-patterns: coisas que parecem tentadoras mas
são erradas aqui. Prefixe com `anti-` no nome do arquivo:

- `anti-nested-useeffect.md`
- `anti-any-in-typescript.md`

## Integração com agentes de IA

As skills `explore` e `find-existing-first` leem esta pasta antes de propor
soluções. Quando um usuário pergunta "como eu deveria lidar com X?", agentes
verificam aqui primeiro. Mantenha os patterns atualizados: patterns
desatualizados enganam ativamente.

## Convenção de nomenclatura

`kebab-case-noun.md`. Os nomes devem se ler como "este arquivo descreve X".

Bom: `structured-logging.md`, `optimistic-updates.md`, `feature-flag-check.md`
Ruim: `logging.md` (muito vago), `how-to-log.md` (verboso), `LoggingPattern.md` (case errado)
