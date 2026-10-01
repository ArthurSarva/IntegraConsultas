# ADR-003 — Autenticação e autorização

Status: proposto; produto, fluxos e parâmetros pendentes.

## Contexto

Contas individuais, funções por vínculo e médico em várias clínicas. MFA para Dev e administradores integra a direção de segurança acordada. Não construir autenticação criptográfica própria.

## Recomendação

Preferir provedor de identidade compatível com OpenID Connect, com MFA, recuperação de conta, revogação e registros de autenticação. Usar biblioteca mantida para integração e sessões.

Fornecedor gerenciado reduz operação inicial, mas precisa de avaliação de preço, contratos, retenção, portabilidade e transferência internacional. Keycloak é alternativa autogerenciada se houver capacidade de operá-lo; não é escolha automática nem hospedagem gratuita.

A identidade externa apenas identifica o usuário. Funções, clínica, escopo e acesso aos pacientes são resolvidos pelo IntegraConsultas, conforme matriz. Não confiar em função enviada pelo navegador.

Sessão web protegida por cookies HttpOnly e Secure em produção, política SameSite compatível com fluxos, proteção CSRF, verificação de origem, limitação de tentativas e expiração. Revogação de vínculo precisa impedir novas ações mesmo com sessão existente.

Separar autenticação da aplicação de OAuth do Google Agenda. Não solicitar Google Calendar como requisito para todos entrarem no sistema.

## Alternativas

- Credenciais próprias com biblioteca: demanda gestão de senhas, recuperação, MFA e resposta a abuso.
- Provedor gerenciado: menor manutenção, dependência comercial e contratual.
- Keycloak: portabilidade e controle, com custo de operação e atualização.

## Consequências

Fornecedor não altera os limites de clínica. Migração de identidades exige mapeamento estável de issuer e subject; email não é identidade imutável. Usuários desligados não devem continuar operando via tokens ou tarefas de exportação.

## Validação antes da escolha

Demonstrar login, MFA, recuperação e revogação com contas fictícias. Avaliar encerramento por inatividade, expiração absoluta, tratamento de conta duplicada, acesso Dev e impossibilidade de autoelevação.

Tempos de sessão, política de MFA dos demais perfis, convite de usuários e concessão Dev ainda serão aprovados. Sem modo de autenticação fictício em produção.

## Fonte

[Keycloak em produção](https://www.keycloak.org/server/configuration-production). Execução local de desenvolvimento não representa configuração de produção.
