# Supabase de desenvolvimento

Configurado em 02/10/2026. Ambiente exclusivo de desenvolvimento, sem dados reais de pacientes e com o primeiro perfil Dev provisionado; nenhuma clínica ou paciente operacional cadastrado.

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
4. 20261002205049_web_session_profile.sql: perfil próprio e contexto da clínica para a base web.

O EXECUTE padrão de PUBLIC é global: uma revogação apenas por schema não o remove. As futuras funções criadas pelo papel postgres precisam de grants explícitos. A alteração global afeta objetos futuros em qualquer schema, incluindo extensões instaladas futuramente; revisar os grants necessários durante cada instalação. Não altera permissões de funções já existentes.

A aplicação remota foi feita pelo conector Supabase, que gera versões próprias. O histórico foi alinhado aos nomes gerados pela CLI no repositório, sem reaplicar DDL: cada atualização de versão exigiu nome, versão anterior e igualdade integral do SQL armazenado, além da ausência da versão de destino. A listagem final contém exatamente as quatro versões acima. Não repetir esse procedimento rotineiramente: a próxima evolução deve usar migrações versionadas, com conferência do histórico antes do envio.

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

As cinco funções api.list_clinics, api.current_clinic, api.select_clinic, api.session_profile e api.workspace têm EXECUTE somente para authenticated. Expor o schema não concede execução ao anônimo. O painel pode indicar zero funções com exposição pública; não habilitar um toggle que conceda anon para eliminar esse indicador.

O banco exige aal2 para Dev e administrador. Habilitar TOTP no serviço permite inscrição/verificação; o fluxo de inscrição e confirmação está implementado na [base web](base-web.md). A configuração local não aplica automaticamente estas opções ao ambiente hospedado.

## Validação realizada

- Seis tabelas com RLS; nenhuma escrita concedida a authenticated nas tabelas da base.
- Acesso direto a private.clinic_contexts negado para authenticated; cinco RPCs sem EXECUTE para anon.
- SQL online sob authenticated sem sessão válida: diretório vazio e contexto nulo.
- Novos objetos de prova em public, criados em transação e desfeitos com rollback: SELECT anônimo, INSERT autenticado e EXECUTE anônimo/autenticado de função não recebem grants automáticos. Não restaram objetos de prova.
- Pela rede, com chave publishable: RPC no perfil api retornou HTTP 401 / SQLSTATE 42501 para acesso anônimo; perfis private, app e public retornaram HTTP 406 / PGRST106.
- Auth settings retornou cadastro desabilitado e confirmação de email exigida.
- 43 verificações SQL locais aprovadas, incluindo os quatro casos de regressão de exposição automática. A suíte com identidades fictícias permanece limitada ao banco descartável; não foi executada no Auth hospedado.
- Na validação inicial da base não havia ERROR/WARN. Após provisionamento do primeiro usuário, o advisor sinalizou proteção contra senhas vazadas desativada (WARN); o recurso exige plano Pro ou superior. Nenhum upgrade foi contratado. Avisos INFO descritos abaixo.

A suíte SQL simula claims de sessão. A base web acrescenta testes separados com Auth real em Supabase descartável para login, cookies, inscrição de MFA, isolamento e revogação. Consulte [base web e testes](base-web.md). O titular concluiu o primeiro login hospedado: perfil Dev ativo, fator TOTP verificado e sessão aal2 válida foram conferidos no banco, sem ler credenciais.

## Avisos informativos

O advisor de segurança informa [RLS sem política em private.clinic_contexts](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy). É intencional: schema privado, sem grants de tabela para usuários comuns e acesso apenas por funções internas protegidas. Não criar uma política permissiva para silenciar o aviso.

O advisor de desempenho informa [cinco índices ainda não usados](https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index). O ambiente está vazio e sem tráfego operacional; os índices sustentam relações e consultas previstas. Reavaliar com uso real antes de removê-los.

## Próxima etapa e limites

Base web de login/recuperação, inscrição de MFA e primeiro Dev implementados. Ainda faltam cadastro administrativo, agenda, pacientes e integrações. Nenhuma clínica ou paciente operacional cadastrado. Sem SMTP próprio nesta etapa. A integração GitHub/Supabase está vinculada conforme a seção abaixo, com implantação automática desabilitada.

Antes de uso real: definir URLs e redirecionamentos da aplicação, provedor de email, provisionamento administrativo, política de sessões, operação de segredos e backup externo com restauração demonstrada. Isolamento, segurança, integridade da agenda, auditoria e recuperação continuam critérios obrigatórios de lançamento.

Evoluções ficam em branches numeradas separadas, com escopo e branch confirmados; merge depende de autorização.

## Integração GitHub

Vínculo ativado e verificado no painel em 02/10/2026:

| Item | Configuração |
| --- | --- |
| Repositório | [ArthurSarva/IntegraConsultas](https://github.com/ArthurSarva/IntegraConsultas) |
| Projeto vinculado | IntegraConsultas-dev |
| Diretório de trabalho | . (raiz do repositório, contendo supabase/) |
| Branch de implantação | sem sincronização ativa; campo de branch desabilitado |
| Deploy to production | desabilitado |
| Automatic branching | desabilitado; indisponível no plano Free |
| Branch limit | 0 |
| Plano | Free, sem upgrade contratado |

A integração está ativa, mas merges e pushes não aplicam automaticamente as migrações ao banco hospedado. A opção chamada “Deploy to production” no painel também controla essa aplicação ao projeto atual, embora este seja nosso ambiente de desenvolvimento. Ativá-la futuramente exige aprovação específica e revisão da branch alvo.

A associação não cria um workflow de publicação, não provisiona Vercel nem adiciona credenciais ao Git. A validação existente no GitHub continua usando Supabase descartável, independente deste banco.

Para conferir ou alterar o vínculo: [Configurações de integrações do projeto](https://supabase.com/dashboard/project/clhcnpxqptgzuxweuaru/settings/integrations). O painel mostrou “Change the connected repository”, “Disable integration” e o repositório correto após a ativação. A configuração foi conferida novamente após recarregar a página.

As branches numeradas de trabalho no GitHub não são branches de banco do Supabase. Preview branches de banco são uma funcionalidade distinta e o painel exige Pro para sua criação automática; não foi habilitada nesta configuração.

## Referências

- [Base local e testes](base-supabase.md)
- [Segurança da API](https://supabase.com/docs/guides/api/securing-your-api)
- [Integração GitHub oficial](https://supabase.com/docs/guides/deployment/branching/github-integration)
- [Histórico de migrações](https://supabase.com/docs/reference/cli/supabase-migration-repair)

