# Backup e restauração — etapa 025

Branch: `025-backup-restauracao`. Esta etapa comprova a recuperação lógica com dados fictícios em ambiente local descartável. Não configura backups online e não autoriza restauração sobre dados reais.

## O que o teste executa

1. Exige um Docker conectado por socket local e o contêiner do Supabase deste projeto. Recusa o ensaio quando o banco local contém usuários ou clínicas.
2. Cria dois bancos temporários com nomes aleatórios. Copia apenas a estrutura dos schemas `auth`, `app`, `private`, `api`, `audit` e `public` do Supabase local para o banco de origem. Inclui separadamente os privilégios padrão globais do banco, que uma exportação filtrada por schema pode omitir.
3. Usa as identidades e os cenários fictícios da suíte SQL para gerar pacientes, consultas, auditoria, permissões e registros de integrações.
4. Gera um arquivo lógico com `pg_dump` em formato customizado, mantido somente em memória. Confere SHA-256 do arquivo junto dos privilégios padrão antes de restaurar com `pg_restore`, em transação única e com interrupção em qualquer erro, e aplicar os privilégios padrão.
5. Compara todas as linhas das tabelas incluídas, valores de sequências e estrutura, incluindo políticas RLS, proprietários, permissões, restrições, índices, funções e gatilhos.
6. Repete a suíte de autorização e agenda usando os papéis PostgreSQL restaurados. Essa segunda verificação usa uma transação revertida e confirma novamente que os dados recuperados foram preservados.
7. Remove somente os bancos que o próprio processo criou. Publica apenas contagens, duração e hash do arquivo, sem publicar registros ou credenciais.

O workflow executa o ensaio após preparar e validar o Supabase local, antes de criar contas para os testes da interface. Para reproduzir, em ambiente **inteiramente descartável**, instalar as dependências, iniciar e recriar o Supabase local e executar `pnpm test:backup:guards` e `pnpm db:test:restore`. Não recriar o banco local usado para trabalho ou demonstração.

## Limites da evidência

Origem e destino usam a mesma versão do PostgreSQL e os mesmos papéis globais do contêiner. O teste preserva permissões; não usa as opções que descartam proprietários ou privilégios. Não é um procedimento de migração para outro projeto gerenciado.

A suíte usa sessões e declarações JWT fictícias para testar autorização SQL. A restauração não comprova login HTTP, MFA ou entrega de email em um novo projeto. Os testes web existentes validam autenticação no Supabase local separadamente.

Ficam fora do arquivo: papéis globais e suas senhas, chaves e configurações de Auth, credenciais OAuth e de criptografia, secrets de funções, arquivos do Storage, configuração de DNS/SMTP, agendamentos Cron e infraestrutura. Nenhum worker é ativado nesses bancos. WhatsApp permanece sem envio.

O SHA-256 detecta alteração do arquivo em relação ao hash esperado; não substitui criptografia ou assinatura. Os arquivos de um backup real devem receber proteção e acesso controlado, pois podem conter dados de pacientes, hashes de senha e tokens de sessão. Uma restauração real exige revogar sessões e revalidar conexões antes de permitir uso.

## Procedimento operacional a concluir antes do lançamento

- Definir e aprovar RPO (perda máxima aceitável), RTO (tempo máximo de recuperação), retenção e responsáveis. Medir recuperação com volume representativo; o tempo da suíte fictícia não define um RTO de produção.
- Escolher armazenamento externo criptografado, com acesso restrito, histórico de versões e verificação periódica. Guardar as chaves de recuperação separadas dos arquivos e fora do Git. Confirmar recursos e retenção do plano contratado.
- Usar o procedimento oficial do Supabase para exportação de roles, schema e dados quando o destino for outro ambiente. Verificar compatibilidade do PostgreSQL, extensões e versões do Auth; preparar destino isolado e vazio.
- Suspender agendamentos e integrações durante a recuperação. Não transportar automaticamente secrets de workers nem ativar envio de mensagens. Conferir pacientes, agenda, auditoria, acesso por clínica, login/MFA e arquivos externos.
- Revogar sessões antigas, recuperar configurações protegidas e reconciliar operações do Google para evitar duplicidade. Liberar acesso após aprovação responsável e registrar evidências, duração e eventuais perdas.
- Executar ensaios periódicos com cópias protegidas e procedimento aprovado. O lançamento continua condicionado à comprovação do processo operacional completo, além deste ensaio automatizado.

Referência: [procedimento oficial de restauração do Supabase e itens não incluídos no banco](https://supabase.com/docs/guides/self-hosting/restore-from-platform).
