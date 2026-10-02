# ADR-003 — Autenticação e autorização

Status: Supabase Auth escolhido em 02/10/2026, conforme [ADR-007](007-supabase.md); fluxos, parâmetros e implementação pendentes.

## Contexto

Contas individuais, funções por vínculo e médico em várias clínicas. MFA para Dev e administradores integra a direção de segurança acordada. Não construir autenticação criptográfica própria.

## Recomendação

Usar Supabase Auth para identidade, MFA e recuperação de conta. Validar integração, revogação e registros antes do lançamento. OpenID Connect permanece alternativa de portabilidade, sem exigir outro provedor no início.

Fornecedor gerenciado reduz operação inicial, mas precisa de avaliação de preço, contratos, retenção, portabilidade e transferência internacional. Keycloak é alternativa autogerenciada se houver capacidade de operá-lo; não é escolha automática nem hospedagem gratuita.

A identidade externa apenas identifica o usuário. Funções, clínica, escopo e acesso aos pacientes são resolvidos pelo IntegraConsultas, conforme matriz. Não confiar em função enviada pelo navegador.

Proposta de sessão com tokens mantidos no servidor e cookie de sessão HttpOnly e Secure no navegador, SameSite compatível com os fluxos, proteção CSRF, verificação de origem, limitação de tentativas e expiração. Validar esse modelo na prova técnica: a integração SSR padrão com cliente Supabase no navegador não garante tokens em cookies HttpOnly. Revogação de vínculo precisa impedir novas ações mesmo com sessão existente.

Permissões persistidas em vínculos controlados pelo sistema, verificadas em cada operação. Não autorizar por user_metadata editável pelo usuário, nem depender exclusivamente de claims antigos do JWT. Exigir MFA para Dev e administradores no servidor e nas políticas pertinentes; método TOTP proposto, recuperação a validar. [Plano de segurança](../supabase.md).

Separar autenticação da aplicação de OAuth do Google Agenda. Não solicitar Google Calendar como requisito para todos entrarem no sistema.

## Alternativas

- Credenciais próprias com biblioteca: demanda gestão de senhas, recuperação, MFA e resposta a abuso.
- Provedor gerenciado: menor manutenção, dependência comercial e contratual.
- Keycloak: portabilidade e controle, com custo de operação e atualização.

## Consequências

Fornecedor não altera os limites de clínica. Migração de identidades exige mapeamento estável de issuer e subject; email não é identidade imutável. Usuários desligados não devem continuar operando via tokens ou tarefas de exportação.

## Validação antes da implantação

Demonstrar login, MFA, recuperação e revogação com contas fictícias. Avaliar encerramento por inatividade, expiração absoluta, tratamento de conta duplicada, acesso Dev e impossibilidade de autoelevação.

Tempos de sessão, política de MFA dos demais perfis, convite de usuários e concessão Dev ainda serão aprovados. Sem modo de autenticação fictício em produção.

## Fonte

[Keycloak em produção](https://www.keycloak.org/server/configuration-production). Execução local de desenvolvimento não representa configuração de produção.
