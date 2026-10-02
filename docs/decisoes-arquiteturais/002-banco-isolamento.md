# ADR-002 — PostgreSQL, isolamento e ocupação global

Status: PostgreSQL no Supabase escolhido em 02/10/2026, conforme [ADR-007](007-supabase.md). Estratégia física de isolamento e ocupação global ainda proposta; não contém SQL ou migrações aprovadas.

## Contexto

Clínicas precisam de isolamento; o mesmo médico não pode ter consultas agendadas ou confirmadas sobrepostas entre clínicas. Essa regra não pode depender da disponibilidade do Google.

## Recomendação

PostgreSQL com esquema compartilhado e clinic_id obrigatório nas entidades operacionais. Combinar autorização no servidor, chaves estrangeiras compostas e políticas de segurança por linha (RLS).

Separar identidades técnicas de aplicação, migrações, automações, auditoria e recuperação conforme privilégio necessário. Aplicação comum não usa superusuário, proprietário das tabelas ou BYPASSRLS. Avaliar FORCE ROW LEVEL SECURITY onde apropriado.

Resolver usuário, vínculo e clínica no servidor e propagar contexto somente dentro da transação; impedir vazamento pelo reaproveitamento de conexões. A capacidade de estabelecer contexto é restrita ao servidor autenticado, nunca a parâmetros arbitrários do cliente.

Para ocupação global, usar identidade médica única e registro mínimo de intervalo. Restrição de exclusão ou equivalente comprovado impede sobreposição para agendada e confirmada. Operações atualizam consulta e ocupação atomicamente. Intervalos seguem convenção semiaberta, permitindo consultas consecutivas; validar na implementação.

Rotina global retorna apenas disponibilidade, com autorização e erros genéricos. Registros globais não são consultáveis pelos perfis comuns. Não expor informações de outra clínica por mensagens de restrição ou IDs.

## Alternativas

- Banco por clínica: isolamento físico maior, mas torna integridade global e operação mais complexas.
- Somente filtros na aplicação: insuficiente como defesa adicional.
- Somente validação prévia: vulnerável a agendamentos simultâneos.
- NoSQL: possível, mas adiciona trabalho para relações e integridade transacional necessárias.

## Consequências

Uma base facilita transações e implantação inicial. RLS demanda testes com a identidade real de aplicação; não basta testar com proprietário. Backup completo contém dados de todas as clínicas e exige proteção adicional.

Rotina global ampliada deve ter superfície mínima, função segura, nomes qualificados, contexto validado e privilégios revogados de usuários comuns. A implementação exata permanece pendente.

## Validação

Testes de acesso cruzado, conexões reutilizadas, duas clínicas agendando simultaneamente, confirmação mantendo ocupação, substituição atômica e revogação de vínculos. Erros não podem revelar dados externos.

## Fontes

- [RLS no PostgreSQL](https://www.postgresql.org/docs/current/ddl-rowsecurity.html)
- [Restrições no PostgreSQL](https://www.postgresql.org/docs/current/ddl-constraints.html)

RLS possui exceções para superusuários/proprietários e regras especiais para integridade referencial. Não presumir isolamento apenas por ativá-la.
