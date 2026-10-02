# Base Supabase — desenvolvimento e validação

Atualização: 02/10/2026. Primeira base executável, limitada à identidade, clínicas, vínculos e seleção de contexto. Sem aplicação web, agenda ou integrações externas nesta etapa.

## Implementado

- CLI Supabase 2.119.0 e PGlite 0.5.8 fixados, com lockfile.
- Configuração local de PostgreSQL 17 padrão, Data API expondo somente api, sem exposição automática de tabelas.
- Cadastro público e login anônimo desabilitados; TOTP habilitado para desenvolvimento.
- app.users ligado ao identificador de auth.users, clínicas, vínculos únicos e funções por vínculo.
- RLS e grants mínimos; sem INSERT/UPDATE/DELETE para usuários comuns nas tabelas da base.
- Diretório autorizado api.list_clinics(), seleção api.select_clinic(uuid) e consulta api.current_clinic().
- Contexto privado separado por sessão Auth, com validação de usuário, vínculo, clínica ativa e expiração/revogação da sessão.
- MFA exigido para Dev e administrador no acesso às clínicas.
- Seleção e auditoria gravadas atomicamente. Administrador lê logs da própria clínica selecionada; Dev lê somente os logs da clínica selecionada.
- Chaves compostas impedem funções ligadas a vínculos de outra clínica.
- Fixtures fictícias exclusivas de teste, executadas em transação desfeita ao final.

As funções privadas SECURITY DEFINER existem para consultas de autorização sem recursão RLS e para seleção auditada. Elas têm search_path vazio, nomes qualificados, verificação do ator autenticado e EXECUTE restrito. O schema private não é exposto; suas tabelas não têm acesso direto por authenticated. As rotas comuns não utilizam service_role.

## Escopo ainda pendente

Não há interface de login/convite, recuperação, cadastro administrativo, perfil Dev inicial, pacientes, profissionais, consultas, ocupação global, lembretes ou Google. Campos/funções de médico e recepção estão representados, mas não implementam autorização de agenda. Não interpretar acúmulo de funções como acesso irrestrito.

Provisionamento de contas, clínicas e vínculos está reservado à identidade técnica até a implementação dos fluxos administrativos auditados. Não oferecer a credencial técnica na aplicação.

O diretório de clínicas permite escolher entre vínculos autorizados (ou catálogo global do Dev). Isso não concede acesso a dados clínicos de todas elas. Futuras operações devem verificar também a clínica esperada pelo pedido contra o contexto, evitando ações na clínica errada após troca em outra aba. Contexto é por sessão: abas da mesma sessão compartilham a seleção; sessões diferentes não.

## Preparação local

Requisitos: Node.js 22 ou superior, pnpm 11.19.0 e Docker compatível para a pilha completa.

```sh
pnpm install --frozen-lockfile
pnpm db:test
pnpm db:start
pnpm db:reset
pnpm db:test:supabase
pnpm db:lint
pnpm db:advisors
pnpm db:stop
```

db:reset é destrutivo apenas para o banco local descartável; não usar em ambientes com dados a preservar. Os scripts explicitam --local e não fazem link, push ou alteração de banco online. Criar projeto online continua etapa separada.

A CLI usa .supabase-home/ local ao checkout por padrão, evitando escrever na pasta pessoal; configurações e caches são ignorados pelo Git. Variável SUPABASE_HOME definida pelo operador prevalece.

.env.example contém somente URL local e campo vazio para chave pública. Nunca incluir senhas, tokens, secret/service_role ou credenciais técnicas no Git. Nenhuma chave é necessária para os testes SQL embarcados.

## Testes e limitações

pnpm db:test cria PostgreSQL embarcado em memória. A migration é aplicada integralmente; fixtures e 39 verificações exercitam SQL real com SET ROLE authenticated/anon, incluindo isolamento, MFA, contexto por sessão, troca de contexto, revogação, autoelevação, auditoria, relações e unicidades.

O suporte Auth embarcado está em tests/support/auth.sql, fora das migrações. Ele simula auth.users, auth.sessions, auth.uid() e auth.jwt(); não valida assinatura de JWT, serviço Auth, PostgREST, cookies, enrollment MFA ou rede. PGlite tem uma conexão; não valida concorrência multiconexão.

pnpm db:test:supabase gera entrada pgTAP a partir das mesmas fixtures e assertions, usando tabelas/funções Auth reais da pilha local. Uma falha SQL interrompe a suíte. O arquivo gerado é ignorado para evitar duplicação divergente. Testes continuam simulando claims de sessão; login e API fim a fim serão uma etapa própria.

Resultado nesta preparação: 39 verificações embarcadas aprovadas. Pilha completa, lint/advisors e lista de migrações não executaram nesta máquina por ausência de banco local/Docker. Workflow do GitHub preparado para executá-los; consultar o resultado do PR antes do merge. Falha estruturada da CLI é tratada como falha mesmo quando o processo retorna código zero.

## Migrações e evolução

Arquivo criado com migration new identity_clinics da CLI. Antes do merge, validar em pilha completa. Depois de integrado, não editar migração aplicada; gerar outra migration para evoluir o esquema.

A configuração de produção precisará ser revisada separadamente: região, conta responsável, SMTP, convites, sessões, proteção de API, segredos e backups. Configuração local não configura automaticamente projeto remoto.

Critérios de lançamento, restauração, integridade da agenda e auditoria completa continuam obrigatórios e ainda não estão comprovados por esta base.

## Referências

- [Arquitetura do banco](arquitetura-banco.md)
- [Permissões](permissoes.md)
- [Supabase e recuperação](supabase.md)
- [CLI oficial](https://supabase.com/docs/guides/local-development/cli/getting-started)
- [RLS](https://supabase.com/docs/guides/database/postgres/row-level-security)
- [Testes de banco](https://supabase.com/docs/guides/database/testing)

