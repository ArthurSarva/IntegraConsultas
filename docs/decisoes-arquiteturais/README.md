# Decisões arquiteturais

Data de preparação: 01/10/2026.

Status: **propostas para revisão, com aprovação parcial de fornecedor**. Em 02/10/2026 foi escolhido Supabase para PostgreSQL e autenticação; detalhes constam no [ADR-007](007-supabase.md). As demais tecnologias, fornecedores, custos e parâmetros operacionais continuam sujeitos à aprovação específica. Requisitos funcionais já acordados continuam obrigatórios.

Cada decisão registra contexto, recomendação, alternativas, consequências e critérios de validação. Para aceitar uma proposta, registrar aprovação e data; substituições futuras devem preservar o histórico.

| Registro | Tema | Status |
|---|---|---|
| [ADR-001](001-aplicacao-web.md) | Aplicação web modular e portabilidade | Proposto |
| [ADR-002](002-banco-isolamento.md) | PostgreSQL, isolamento e ocupação global | PostgreSQL escolhido; isolamento físico proposto |
| [ADR-003](003-autenticacao.md) | Autenticação e autorização | Proposto; Supabase Auth escolhido |
| [ADR-004](004-automacoes.md) | Tarefas persistidas e integrações | Proposto |
| [ADR-005](005-ambientes-operacao.md) | Ambientes, hospedagem e recuperação | Proposto; banco no Supabase escolhido |
| [ADR-006](006-validacao-entrega.md) | Validação e entrega por etapas | Proposto |
| [ADR-007](007-supabase.md) | Supabase para banco e autenticação | Fornecedor aceito em 02/10/2026; operação a validar |

## Antes de iniciar a base executável

1. Aprovar ou ajustar aplicação, estratégia física do banco e automação.
2. Validar Supabase Auth, MFA, recuperação e revogação de acesso.
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
