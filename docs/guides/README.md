# docs/guides/

Onboarding, how-tos e tutoriais para humanos trabalhando neste projeto.

## O que vai aqui

- Getting started (setup local, primeira PR)
- Guia de testes (como escrever testes aqui, o que testar)
- Guia de debugging (problemas comuns, ferramentas)
- Guia de contribuição (se não estiver no `CONTRIBUTING.md` da raiz)
- Guias específicos de feature ("como adicionar uma nova rota de API")

## O que NÃO vai aqui

- Procedimentos operacionais: vão em `docs/runbooks/`
- Contexto arquitetural: vai em `docs/architecture/`
- Decisões de design: vão em `docs/decisions/`
- Referência de API: gerada automaticamente ou hospedada separadamente

## Formato

Guias são mais narrativos do que runbooks. Podem ser em prosa, em estilo
tutorial. Eles explicam o "por quê" tanto quanto o "como".

Um bom guia tem:

- Um público-alvo claro (para quem é isso)
- Pré-requisitos (o que você deveria saber antes)
- Exemplos concretos com caminhos de arquivo reais
- Uma seção de "próximos passos" apontando para material relacionado

## Guias sugeridos para criar

- `getting-started.md` - clonar, instalar, primeira execução bem-sucedida
- `local-setup.md` - variáveis de ambiente, banco de dados, serviços externos
- `testing.md` - estrutura de testes, convenções, como escrever bons testes
- `adding-a-feature.md` - passo a passo do fluxo guiado por spec com um exemplo pequeno

## Integração com agentes de IA

Agentes leem guias quando precisam ajudar o usuário com um fluxo de trabalho
que ainda não fizeram. Guias bem escritos significam que o agente dá
respostas precisas e específicas do projeto em vez de conselhos genéricos.
