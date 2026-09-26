# `script/setup` e `script/test`: Scripts to Rule Them All

Para quem precisa ir de um clone recém-feito (ou um worktree recém-feito) até
um ambiente funcional e verificado, sem precisar rededuzir os passos a partir de prosa.

## Pré-requisitos

Nenhum além do próprio repositório. Este guia descreve dois scripts que você
escreve **uma vez, por projeto** (o harness não os distribui e não os gera).
Ele só os chama quando existem.

## Por quê

Configuração de ambiente escrita apenas como prosa (`AGENTS.md`, uma seção do
README) precisa ser redescoberta por todo humano e todo agente que precisa
dela: lida, e depois traduzida em comandos, todas as vezes. Em um projeto,
isso significou reexplicar as mesmas ~15 linhas de ambiente (versão do
runtime, qual comando de lint só verifica versus também reescreve arquivos,
qual comando é de fato o gate) em dezenas de briefings de subagente, apesar
de tudo isso já estar escrito em algum lugar. A documentação não era o
problema; nada a executava.

A correção, tomada de empréstimo da convenção [Scripts to Rule Them All](https://github.com/github/scripts-to-rule-them-all)
do GitHub, é dois scripts executáveis, commitados na raiz do repositório, que
humanos, CI e agentes todos executam da mesma forma:

- **`script/setup`**: leva um clone ou worktree de zero a "pronto para
  trabalhar". Idempotente: seguro de executar de novo num checkout já configurado.
- **`script/test`**: a verificação que este repositório considera um gate. O
  único comando que precisa estar verde antes de uma mudança contar como concluída.

A própria skill `spec-worktree` do harness executa `script/setup`
automaticamente depois de criar um worktree (pule com `--no-setup`), e o
`verify-before-done` executa `script/test` em vez de redescobrir comandos,
quando qualquer um dos dois existe. Um projeto sem nenhum dos dois scripts não
é afetado: ambos são no-ops.

## O que um bom `script/setup` faz

- Fixa a versão do runtime primeiro, antes de instalar qualquer coisa
  (`.nvmrc`, `.tool-versions`, o que o repositório fixar). Instalar
  dependências sob o runtime errado é uma fonte comum de falhas que parecem
  não ter relação com a causa real.
- Instala dependências.
- Cria o arquivo de ambiente local **a partir de um exemplo versionado, só se
  ele ainda não existir** (nunca sobrescreve um arquivo que tenha valores
  locais reais). Se o exemplo lista variáveis que o script não pode
  preencher (segredos, credenciais por desenvolvedor), ele lista exatamente
  quais estão faltando e onde obtê-las; nunca inventa um valor.
- Executa codegen, se o repositório tiver algum (client de ORM, tipos de API gerados).
- Termina executando `script/test` e registrando o resultado (ex.: "42
  passing") em algum lugar visível, para que a primeira execução verde seja
  uma baseline conhecida e reprodutível, não uma suposição.

Exemplo mínimo (projeto Node):

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# 1. Versão do runtime
if [ -f .nvmrc ] && command -v nvm >/dev/null; then
  nvm install >/dev/null
  nvm use
fi

# 2. Dependências
yarn install

# 3. Arquivo de ambiente local, a partir do exemplo, só se estiver faltando, nunca sobrescrito
if [ -f .env.example ] && [ ! -f .env ]; then
  cp .env.example .env
  echo "Created .env from .env.example - fill in the values it needs."
fi

# 4. Codegen (se aplicável)
[ -f prisma/schema.prisma ] && npx prisma generate

# 5. Baseline: executa o gate uma vez, sabe como é o verde
./script/test
```

## O que um bom `script/test` faz

- Executa os mesmos comandos que um humano ou o CI executariam (typecheck,
  build, a suíte de testes, lint). ELE É o gate; nada downstream deveria
  precisar redescobrir o que "verificado" significa para este repositório.
- Nunca usa um comando que reescreve arquivos como efeito colateral (ex.:
  lint com `--fix`, um formatador em modo de escrita). Um gate que pode mudar
  silenciosamente o código que está verificando não é um gate, é um editor
  com um código de saída confuso. Use a variante somente-verificação.
- Executa a suíte ao menos uma vez sob uma variação barata de ambiente (um
  timezone diferente, `TZ=UTC`, um locale diferente) quando a stack suporta
  isso facilmente. Uma suíte que só roda no próprio timezone da máquina pode
  estar verde por acidente daquela máquina, e o acidente não viaja para o CI
  ou para o laptop de um colega.

Exemplo mínimo:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

npx tsc --noEmit
TZ=UTC yarn test
yarn lint          # só verificação; nunca --fix aqui
```

## Próximos passos

- Se este repositório ainda não tem esses scripts, o `analyze-codebase`
  aponta essa lacuna no relatório dele ao adotar o harness num projeto
  existente (ele não os escreve para você, já que só o time sabe o que
  "pronto" e "verificado" significam aqui).
- Veja `.claude/scripts/harness/spec-worktree.sh` (via a skill
  `spec-worktree`) para onde `script/setup` é chamado automaticamente, e a
  skill `verify-before-done` para onde `script/test` se torna o gate.
