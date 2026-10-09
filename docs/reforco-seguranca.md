# Reforço de segurança — etapa 024

Esta etapa depende da 023 e mantém o WhatsApp bloqueado. Não altera usuários, credenciais, configurações do Auth ou dados clínicos do Supabase online. Não representa autorização de lançamento.

## Alteração de senha

Antes, qualquer sessão autenticada conseguia chamar a ação de alteração de senha da aplicação. Agora, a página e a ação verificam usuário atual, fatores cadastrados e claims assinadas verificadas pelo Supabase. A ação exige também renovação válida da sessão antes da alteração, recusando refresh token revogado. As claims devem pertencer ao mesmo usuário retornado por `getUser`; metadados editáveis não concedem acesso.

- Com autenticador TOTP verificado, é necessário `aal2` e evidência TOTP dos últimos cinco minutos, reconhecendo `mfa/totp` e o identificador anterior `totp`. Se faltar, a tela pede código; o servidor faz novo desafio no fator da própria conta e confere o resultado antes de atualizar a senha.
- Um convite ou recuperação não dispensa um autenticador já cadastrado. Perda do autenticador continua exigindo recuperação assistida, fora desta etapa.
- Sem autenticador, definição inicial e recuperação exigem evidência recente de verificação do link, com janela de dez minutos. Uma sessão comum por senha não basta; a página encaminha para solicitar recuperação.
- Supabase `verifyOtp` emite evidência `otp` nos fluxos de convite e recuperação. Essa evidência não distingue o tipo do link; a política aceita autenticação OTP recente verificada, além das evidências explícitas `invite` ou `recovery` quando presentes. A aplicação oferece somente os fluxos já existentes de convite e recuperação.
- Renovação do JWT não renova a janela: o horário considerado vem de `amr`, não de `iat`. Horários futuros, ausentes ou malformados não autorizam a operação.
- Após sucesso, o encerramento global das sessões e a exigência de novo login são preservados. Tokens de acesso previamente emitidos podem durar até sua expiração; operações clínicas continuam verificando sessão e permissões no banco.

Esta política protege a ação da aplicação. Não substitui as regras próprias do endpoint Auth do Supabase para clientes que disponham diretamente de um JWT. Revisar a configuração de troca segura de senha do Auth permanece uma tarefa de preparação para produção; esta etapa não habilita uma garantia universal de recência em APIs externas.

## Proteção das páginas

O proxy gera um nonce imprevisível por requisição e sobrescreve qualquer nonce ou CSP recebido do cliente. A política é passada ao renderizador e à resposta, mesmo quando a renovação da sessão recria a resposta. Cookies de autenticação e instruções de não armazenar a resposta são preservados.

Scripts precisam da política com nonce e `strict-dynamic`; `unsafe-inline` não é permitido para scripts. A política bloqueia objetos, inserção de URL base, incorporação por outras páginas, envio de formulário a outro domínio e conexões do navegador a origens externas. As integrações atuais fazem suas chamadas no servidor.

Imagens `data:` permanecem permitidas para o QR do autenticador. Estilos inline continuam permitidos por compatibilidade, portanto esta etapa não elimina toda possibilidade de injeção visual. `unsafe-eval` e WebSocket local são permitidos somente no desenvolvimento, para as ferramentas do Next.js.

Todas as páginas são renderizadas dinamicamente para que scripts e nonce correspondam à requisição. Isso reduz a oportunidade de cache de HTML público e aumenta o custo de renderização; é uma escolha consciente para esta aplicação autenticada. A CSP complementa autorização, validação e proteção dos dados, sem substituí-las.

## HTTPS

HSTS com prazo de um ano é configurado somente quando `APP_ORIGIN` usa HTTPS e o ambiente é de produção. Não inclui subdomínios nem preload. A atualização automática de requisições inseguras também depende de HTTPS em produção. Desenvolvimento local HTTP continua funcionando.

Antes de publicar, configurar a origem HTTPS correta tanto na compilação quanto na execução, validar certificado e verificar os cabeçalhos no endereço público. Não ativar HSTS num domínio sem HTTPS operacional.

## Testes e pendências

Testes unitários verificam recência de MFA e OTP, expiração, ausência de prova, metadados falsos, datas futuras, restrições de CSP e condições de HSTS. Testes web usam somente Supabase descartável e cobrem nonce distinto, tentativa de injeção, funcionamento dos formulários, bloqueio de sessão comum, recuperação com MFA e mudança com código válido. Os testes existentes de convite, recuperação e clínica continuam obrigatórios.

Pendências de lançamento incluem proteção contra senhas vazadas no Auth, revisão de credenciais e privilégios técnicos, revogação externa no desligamento Google, operação do WhatsApp e comprovação de restauração de backups. Nenhuma dessas pendências é considerada resolvida apenas por esta etapa.

Referências: [claims JWT do Supabase](https://supabase.com/docs/guides/auth/jwt-fields), [verificação de OTP no Supabase Auth](https://github.com/supabase/auth/blob/master/internal/api/verify.go), [CSP no Next.js](https://nextjs.org/docs/app/guides/content-security-policy). Os guias da versão instalada foram consultados antes da implementação.

