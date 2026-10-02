# Supabase de desenvolvimento

Configurado em 02/10/2026. Ambiente exclusivo de desenvolvimento, sem dados reais de pacientes e sem contas operacionais provisionadas.

## Identificação

| Item | Valor |
| --- | --- |
| Organização | IntegraConsultas |
| Projeto | IntegraConsultas-dev |
| Referência | clhcnpxqptgzuxweuaru |
| Região | São Paulo, sa-east-1 |
| Plano na criação | Free; custo informado US$ 0/mês |
| Banco observado | PostgreSQL 17.11.0.002 |
| API URL | https://clhcnpxqptgzuxweuaru.supabase.co |
| Painel | https://supabase.com/dashboard/project/clhcnpxqptgzuxweuaru |

Referência e URL identificam o ambiente; não são credenciais. Obter chaves no painel e mantê-las fora do Git. Preferir a chave publishable no futuro cliente; nenhuma secret/service_role pode ir para o navegador.

## Estrutura aplicada

A migração de identidade foi obtida da main no commit 8820e788e3c9f250321934977d58978fb3bb9232. Foram aplicadas, em ordem:

1. 20261002192130_identity_clinics.sql: identidade, clínicas, vínculos, funções, contexto por sessão, auditoria, RLS e grants.
2. 20261002202342_harden_public_defaults.sql: revogação dos grants automáticos de novos objetos em public.
3. 20261002202446_revoke_public_function_defaults.sql: revogação global do EXECUTE padrão de funções para PUBLIC e papéis de API.

O EXECUTE padrão de PUBLIC é global: uma revogação apenas por schema não o remove. As futuras funções criadas pelo papel postgres precisam de grants explícitos. A alteração global afeta objetos futuros em qualquer schema, incluindo extensões instaladas futuramente; revisar os grants necessários durante cada instalação. Não altera permissões de funções já existentes.

A aplicação remota foi feita pelo conector Supabase, que gera versões próprias. O histórico foi alinhado aos nomes gerados pela CLI no repositório, sem reaplicar DDL: cada atualização de versão exigiu nome, versão anterior e igualdade integral do SQL armazenado, além da ausência da versão de destino. A listagem final contém exatamente as três versões acima. Não repetir esse procedimento rotineiramente: a próxima evolução deve usar migrações versionadas, com conferência do histórico antes do envio.

## Configurações do serviço

| Área | Configuração verificada |
| --- | --- |
| Schemas expostos na Data API | somente api |
| Schemas internos | app, private e audit não expostos |
| public e graphql_public | retirados da exposição |
| Extra search path | extensions |
| Exposição automática | grants padrão de tabelas, sequências e funções revogados por migração |
| Limite de resultados | 1.000 linhas |
| Cadastro público | desabilitado |
| Login anônimo | desabilitado, confirmado no painel |
| Email | habilitado, confirmação de endereço exigida |
| MFA TOTP | habilitado, confirmado no painel |
| Sessões AAL1 com fator inscrito | limitação de 15 minutos do serviço mantida |
| MFA SMS | desabilitado; não necessário nesta etapa |

As três funções api.list_clinics, api.current_clinic e api.select_clinic têm EXECUTE somente para authenticated. Expor o schema não concede execução ao anônimo. O painel pode indicar zero funções com exposição pública; não habilitar um toggle que conceda anon para eliminar esse indicador.

O banco exige aal2 para Dev e administrador. Habilitar TOTP no serviço permite inscrição/verificação; o fluxo de MFA da aplicação ainda será implementado. A configuração local não aplica automaticamente estas opções ao ambiente hospedado.

## Validação realizada

- Seis tabelas com RLS; nenhuma escrita concedida a authenticated nas tabelas da base.
- Acesso direto a private.clinic_contexts negado para authenticated; três RPCs sem EXECUTE para anon.
- SQL online sob authenticated sem sessão válida: diretório vazio e contexto nulo.
- Novos objetos de prova em public, criados em transação e desfeitos com rollback: SELECT anônimo, INSERT autenticado e EXECUTE anônimo/autenticado de função não recebem grants automáticos. Não restaram objetos de prova.
- Pela rede, com chave publishable: RPC no perfil api retornou HTTP 401 / SQLSTATE 42501 para acesso anônimo; perfis private, app e public retornaram HTTP 406 / PGRST106.
- Auth settings retornou cadastro desabilitado e confirmação de email exigida.
- 43 verificações SQL locais aprovadas, incluindo os quatro casos de regressão de exposição automática. A suíte com identidades fictícias permanece limitada ao banco descartável; não foi executada no Auth hospedado.
- Consultados advisors de segurança e desempenho: nenhum ERROR/WARN observado. Avisos INFO descritos abaixo.

A suíte local e a suíte Supabase no GitHub simulam claims de sessão. Não validam login real, assinatura de JWT, cookies, inscrição de MFA ou CRUD da aplicação. Os resultados da pilha completa para esta branch ficam na execução do PR.

## Avisos informativos

O advisor de segurança informa [RLS sem política em private.clinic_contexts](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy). É intencional: schema privado, sem grants de tabela para usuários comuns e acesso apenas por funções internas protegidas. Não criar uma política permissiva para silenciar o aviso.

O advisor de desempenho informa [cinco índices ainda não usados](https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index). O ambiente está vazio e sem tráfego operacional; os índices sustentam relações e consultas previstas. Reavaliar com uso real antes de removê-los.

## Próxima etapa e limites

Ainda faltam aplicação web, login/convites/recuperação, inscrição de MFA, perfil Dev inicial, cadastro administrativo, agenda e integrações. Não foram criados usuários, clínicas ou pacientes operacionais. Sem SMTP próprio ou integração automática GitHub/Supabase nesta etapa.

Antes de uso real: definir URLs e redirecionamentos da aplicação, provedor de email, provisionamento administrativo, política de sessões, operação de segredos e backup externo com restauração demonstrada. Isolamento, segurança, integridade da agenda, auditoria e recuperação continuam critérios obrigatórios de lançamento.

Evoluções ficam em branches numeradas separadas, com escopo e branch confirmados; merge depende de autorização.

## Referências

- [Base local e testes](base-supabase.md)
- [Segurança da API](https://supabase.com/docs/guides/api/securing-your-api)
- [Histórico de migrações](https://supabase.com/docs/reference/cli/supabase-migration-repair)
