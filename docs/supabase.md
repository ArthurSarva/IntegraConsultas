# Supabase — adoção e operação

Atualização: 02/10/2026. Supabase aprovado para PostgreSQL e autenticação. Este plano orienta as próximas etapas; não representa configuração realizada.

## Ambientes e plano gratuito

| Ambiente | Uso | Dados |
|---|---|---|
| Desenvolvimento/testes | Validar migrações, permissões e integrações simuladas | Fictícios |
| Produção | Operação clínica após critérios de lançamento | Reais somente após validação |

Projetos separados possuem banco, identidade e credenciais independentes. Todas as clínicas compartilham o banco do respectivo ambiente, com isolamento lógico; não criar projeto por clínica.

Limites consultados em 02/10/2026: dois projetos gratuitos ativos, somados entre organizações em que a conta seja proprietária ou administradora; 500 MB de banco por projeto; 5 GB de saída de dados na cota da organização; pausa após uma semana de inatividade; backups automáticos e recuperação por instante (PITR) não incluídos. Revalidar limites antes da criação e acompanhar consumo, inclusive índices e auditoria.

Definir responsável pela conta e região disponível antes de criar os projetos. Não assumir residência dos dados, aprovação contratual ou conformidade automática com LGPD pela escolha do serviço. Registrar região e avaliação do fornecedor conforme [privacidade](privacidade-seguranca.md).

Hospedagem da aplicação web, execução das automações, WhatsApp, Google OAuth e eventual SMTP não estão cobertos pela escolha do banco. Não criar tráfego artificial para evitar pausa. Operação deve detectar indisponibilidade e proteger a execução dos lembretes.

## Autenticação

Supabase Auth identifica a conta; funções e escopos permanecem em vínculos do IntegraConsultas. Mapear o identificador estável do usuário, sem usar email como chave imutável.

Validar convite, login, recuperação, revogação, limitação de tentativas e sessões. Não permitir que cadastro público conceda Dev ou vínculo com clínica. MFA obrigatório para Dev e administrador; TOTP é a proposta inicial, com recuperação a definir e verificação efetiva no servidor e nas políticas pertinentes.

Não usar user_metadata editável pelo usuário para conceder acesso. Revalidar vínculos ativos nas operações; JWT existente não garante permissão atual após desligamento.

A arquitetura de sessão será demonstrada antes de implementação definitiva. A proposta de tokens no servidor e cookies HttpOnly exige integração específica; não atribuir essa garantia automaticamente ao cliente SSR padrão.

## Isolamento e privilégios

- Validar usuário, função, vínculo ativo e clínica no servidor; clinic_id do navegador não autoriza acesso.
- RLS em todas as tabelas de schemas expostos, com políticas por operação e escopo; somente estar autenticado não concede acesso clínico.
- Restringir tabelas de vínculos, funções e ocupação global; usuários não podem conceder privilégios a si mesmos.
- INSERT e UPDATE precisam validar a clínica de destino; relações impedem associação entre clínicas.
- Dev seleciona uma clínica para dados operacionais; administração global é separada. Exportação continua restrita ao administrador vinculado.
- Médico vê própria agenda e pacientes de suas consultas; médico com recepção gerencia somente sua agenda.
- Views devem respeitar RLS ou ficar sem acesso público. Funções privilegiadas precisam de superfície mínima, schema não exposto, autorização explícita e privilégios restritos.
- Chaves secretas/service_role nunca no navegador ou repositório. Rotas clínicas comuns usam identidade sujeita a RLS, não uma chave que a ignore.
- Automações e administração técnica usam permissões mínimas, escopo explícito e auditoria.

Políticas, SQL e modelo de conexão serão verificados com identidades reais de aplicação, incluindo troca de contexto e conexões reutilizadas. Seguir [modelo](modelo-dados.md), [permissões](permissoes.md) e [ADR-002](decisoes-arquiteturais/002-banco-isolamento.md).

## Integridade e auditoria

Garantir no banco que agendada e confirmada ocupem o intervalo e que o mesmo médico não tenha sobreposição entre clínicas. Retornar apenas indisponibilidade para conflitos externos, sem dados da outra clínica.

Consulta, ocupação e tarefas persistidas devem mudar atomicamente. Substituição cancela a anterior, preserva histórico e invalida ações antigas; reagendamento exige nova confirmação.

Registrar ações e acessos conforme política do sistema. Logs temporários do provedor não substituem auditoria clínica. Limitar conteúdo e retenção sem eliminar evidências obrigatórias.

## Backups e restauração — estratégia proposta

Como o plano gratuito não inclui backups automáticos, preparar exportação periódica com ferramenta compatível, criptografia e destino externo ao projeto. Frequência, retenção, responsável, armazenamento e metas de recuperação permanecem pendentes; não considerar esta proposta como rotina implantada.

Inventariar tabelas clínicas, vínculos, auditoria, schemas, políticas, funções e dados de Auth necessários à recuperação. Testar cobertura do método de exportação; um dump padrão não deve ser presumido completo. Arquivos de Storage, se adotados, exigem cópia própria. Configurações, segredos e chaves de recuperação ficam em armazenamento seguro separado, nunca no Git.

Monitorar sucesso, falha e idade das cópias. Registrar restauração real em ambiente isolado, verificando acesso, vínculos, RLS, relações, ocupação e auditoria. Medir perda de dados e tempo de recuperação; RPO/RTO numéricos seguem pendentes.

Antes de reativar automações após restauração, reconciliar mensagens e eventos já enviados para evitar duplicações. Testes com dados reais restaurados exigem proteção equivalente à produção; dados reais não podem ser copiados para o ambiente comum de desenvolvimento.

## Etapas e evidências

1. Criar projetos e registrar região, responsáveis e configurações sem segredos.
2. Preparar migrações versionadas e dados fictícios.
3. Demonstrar autenticação, MFA, revogação e impossibilidade de autoelevação.
4. Testar isolamento de leitura e escrita, permissões por perfil e Dev com clínica selecionada.
5. Testar concorrência, ocupação entre clínicas e substituição atômica.
6. Executar exportação e restauração isolada, com evidências.
7. Confirmar todos os [critérios de lançamento](qualidade-lancamento.md) antes do piloto real.

Cada parte em branch numerada própria, com descrição e autorização prévia. Nenhum projeto, usuário, tabela ou rotina foi criado por esta atualização documental.

## Fontes consultadas

- [Planos](https://supabase.com/pricing)
- [Organizações e limites](https://supabase.com/docs/guides/platform/billing-on-supabase)
- [RLS](https://supabase.com/docs/guides/database/postgres/row-level-security)
- [Chaves](https://supabase.com/docs/guides/getting-started/api-keys)
- [MFA](https://supabase.com/docs/guides/auth/auth-mfa)
- [Sessão SSR](https://supabase.com/docs/guides/auth/server-side)
- [Backups](https://supabase.com/docs/guides/platform/backups)
- [Changelog](https://supabase.com/changelog)
