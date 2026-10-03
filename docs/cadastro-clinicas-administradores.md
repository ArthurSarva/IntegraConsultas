# Cadastro de clínicas e administradores

Escopo da branch `012-cadastro-clinicas-administradores`: o Dev cadastra uma clínica e, depois de selecioná-la, vincula administradores. Agenda, pacientes e cadastro dos demais perfis continuam em etapas futuras.

## Fluxo

```mermaid
flowchart TD
    A[Dev autenticado com duas etapas] --> B[Cadastrar clínica e fuso horário]
    B --> C[Selecionar a clínica]
    C --> D[Informar nome e email do administrador]
    D --> E{Conta já confirmada?}
    E -->|Sim| F[Vincular conta existente sem alterar senha]
    E -->|Não| G[Gerar convite e vincular administrador]
    G --> H[Dev copia e entrega o link individual]
    H --> I[Administrador aceita convite de uso único]
    I --> J[Administrador define sua própria senha]
    J --> K[Entrar e configurar autenticador]
    F --> K
    K --> L[Acessar somente clínicas às quais está vinculado]
```

## Autorização e integridade

Cada operação verifica a identidade no Supabase Auth, a validade da sessão no banco, o cadastro ativo, o perfil Dev armazenado no banco e o nível de autenticação `aal2`. A vinculação exige que a clínica informada seja a clínica selecionada naquela sessão. Recepção, médico e administrador não podem executar estes cadastros globais.

As funções expostas em `api` delegam a funções privadas com contexto controlado. Escrita direta nas tabelas continua bloqueada. Cada cadastro recebe um identificador de operação: repetir a mesma operação com os mesmos dados devolve o resultado anterior; reutilizar o identificador com dados diferentes é recusado. Cadastro e auditoria do banco são atômicos.

A conta criada recebe apenas o papel de administrador naquela clínica. Não recebe Dev. Contas ou vínculos inativos não são reativados automaticamente. Uma conta confirmada mantém sua senha e, quando já possui cadastro no sistema, seu nome global. Os eventos `clinic.created` e `administrator.linked` registram ator, clínica, alvo e identificador da operação, sem senha ou token de convite.

## Convite e senha

A função `provision-administrator` usa a credencial privilegiada exclusivamente para gerar o convite no Auth. Valida o JWT com `getUser` e as permissões com as funções do banco antes de gerar o convite; a concessão final também verifica o contexto. O cadastro de papéis utiliza a identidade do Dev, sem contornar as permissões com a credencial privilegiada.

O link é entregue manualmente pelo Dev, sem email automático. O segredo fica no fragmento `#token=`, que não é enviado no endereço HTTP. A tela remove esse fragmento do histórico imediatamente e só consome o convite quando a pessoa confirma o aceite. O convite é pessoal, expira conforme a configuração do Auth e só pode ser aceito uma vez. Não compartilhar em grupos nem registrar em chamados, logs ou Git.

O administrador escolhe a senha, entra e configura seu próprio autenticador. Nenhuma senha deve passar pelo Dev. O link aparece somente no resultado do cadastro; recarregar a página o descarta. Repetir o cadastro de uma conta ainda não confirmada permite gerar outro convite. Repetir para conta confirmada não redefine sua senha.

A leitura do fragmento acontece uma única vez por montagem da tela, inclusive quando o Strict Mode repete os efeitos em desenvolvimento. O código fica somente em memória: atualizar a tela de aceite depois da remoção do fragmento não o recupera. Se ainda não aceitou, reabra o link completo originalmente recebido; não compartilhe esse link no chat ou nos logs.

O comando `pnpm test:invite:dev` verifica a leitura em `next dev`, a remoção do fragmento, a ausência de persistência após recarregar e a recusa de uma página sem código. Usa códigos fictícios e nunca confirma o aceite. O CI inicia seu próprio servidor; localmente pode reutilizar a prévia já aberta. Para usar um Chrome instalado, definir `PLAYWRIGHT_CHANNEL=chrome`; sem essa opção, usa o Chromium do Playwright. O fluxo completo de aceite continua coberto pela suíte de produção com Supabase descartável.

Auth e concessão de acesso pertencem a operações distintas: uma falha depois da criação da identidade pode deixar uma conta pendente sem acesso à clínica. Nesse caso, tentar novamente. O sistema não remove automaticamente a identidade, pois ela pode ter sido usada por outra clínica durante a operação.

## Ambiente e validação

`APP_ORIGIN` determina a origem do link e deve ser HTTPS público para uso externo. No desenvolvimento com `http://127.0.0.1:3000`, o link funciona apenas no computador onde a aplicação está executando. Publicação web, SMTP e recuperação de senha em produção permanecem pendentes.

Os testes utilizam contas fictícias e Supabase local descartável. Cobrem isolamento, Dev com MFA, clínica selecionada, repetição de operações, conta inativa, convite, senha definida pelo destinatário, rejeição de convite já usado, preservação da senha de conta existente e rejeição de chamadas anônimas ou feitas pela recepção. Não criam clínicas ou administradores reais no ambiente hospedado.

A função verifica a autorização internamente; `verify_jwt=false` desliga apenas a verificação automática do gateway, não permite acesso anônimo ao cadastro. Falhas retornam mensagens genéricas. Logs de argumentos de ações e requisições do Next em desenvolvimento ficam desativados. Na hospedagem, manter também a ocultação de segredos nos logs da plataforma e proxies.

## Cancelamento de convite

Na lista de administradores, o Dev pode cancelar um convite pendente da clínica selecionada. O botão aparece ao lado do status; contas confirmadas não apresentam essa ação. O sistema retira apenas o papel de administrador daquela clínica, mantém a identidade e os vínculos em outras clínicas e registra `administrator.invitation_cancelled` na auditoria. Repetir uma operação não duplica o evento. Repetir uma operação antiga depois de emitir novo convite é recusado.

A função de autenticação substitui o token pendente por outro que é descartado, sem enviar email. Só apresenta “Convite cancelado” após verificar no banco que o token foi substituído ou já consumido. Se o Auth falhar, o acesso permanece cancelado e a lista oferece “Concluir cancelamento”. O fingerprint privado permite verificar a substituição sem guardar o token original. A tabela privada tem RLS e nenhuma permissão direta de leitura ou escrita para clientes.

O token de convite pertence à conta Auth, portanto invalidar o link também invalida links pendentes da mesma conta que tenham sido entregues em outro contexto. Os papéis e vínculos das outras clínicas são preservados. Contas confirmadas e suas senhas não são alteradas. Para emitir um novo convite depois do cancelamento, repetir explicitamente o cadastro; não reutilizar a operação anterior.

Os testes verificam cancelamento, auditoria única, proteção contra replay, isolamento, preservação de vínculos e recusa de cancelamento de conta confirmada. A suíte com Supabase descartável também verifica pelo Auth que o token antigo foi invalidado e que um convite novo funciona. Nenhum convite real é cancelado pelos testes.
