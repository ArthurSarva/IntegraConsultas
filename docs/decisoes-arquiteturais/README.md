# Decisões arquiteturais

Data de preparação: 01/10/2026.

Status: **propostas para revisão**. A autorização para criar esta documentação não aprova automaticamente tecnologias, fornecedores, custos ou parâmetros operacionais. Requisitos funcionais já acordados continuam obrigatórios.

Cada decisão registra contexto, recomendação, alternativas, consequências e critérios de validação. Para aceitar uma proposta, registrar aprovação e data; substituições futuras devem preservar o histórico.

| Registro | Tema | Status |
|---|---|---|
| [ADR-001](001-aplicacao-web.md) | Aplicação web modular e portabilidade | Proposto |
| [ADR-002](002-banco-isolamento.md) | PostgreSQL, isolamento e ocupação global | Proposto |
| [ADR-003](003-autenticacao.md) | Autenticação e autorização | Proposto; fornecedor pendente |
| [ADR-004](004-automacoes.md) | Tarefas persistidas e integrações | Proposto |
| [ADR-005](005-ambientes-operacao.md) | Ambientes, hospedagem e recuperação | Proposto; fornecedor pendente |
| [ADR-006](006-validacao-entrega.md) | Validação e entrega por etapas | Proposto |

## Antes de iniciar a base executável

1. Aprovar ou ajustar aplicação, banco e estratégia de automação.
2. Escolher solução de autenticação e validar MFA e recuperação de conta.
3. Definir ambiente inicial local; demonstrador remoto somente com dados fictícios.
4. Escolher ferramenta de acesso ao banco e migrações por prova técnica das restrições e do contexto transacional.
5. Fixar versões suportadas e dependências no início da implementação.
6. Criar implementação em branch própria, com autorização do conteúdo e nome.

## Referências internas

- [Requisitos](../requisitos-funcionais.md)
- [Permissões](../permissoes.md)
- [Modelo de dados](../modelo-dados.md)
- [Critérios de lançamento](../qualidade-lancamento.md)

Não contratar, implantar ou utilizar dados reais como consequência automática deste PR.
