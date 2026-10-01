# Arquitetura proposta

Status: proposta técnica; stack e fornecedores ainda não aprovados definitivamente.

## Componentes

| Componente | Proposta |
|---|---|
| Aplicação web e servidor | Next.js e TypeScript |
| Persistência | PostgreSQL gerenciado |
| Automação | Processo em segundo plano com tarefas persistidas |
| Comunicação | API oficial de WhatsApp |
| Calendário | API oficial do Google Agenda com OAuth |
| Portabilidade | Contêineres e configuração por ambiente |

Uma aplicação organizada em módulos e um processo de automação no mesmo repositório são a proposta inicial.

## Fluxo

1. Usuário autenticado seleciona clínica autorizada.
2. Servidor valida função, escopo, disponibilidade e integridade.
3. Consulta e tarefas de automação são persistidas na mesma transação.
4. Processador lê tarefas e verifica versão e situação atual da consulta.
5. Adaptadores enviam mensagens e sincronizam eventos.
6. Retornos dos fornecedores atualizam histórico e situação das tarefas.

## Isolamento

Todas as entidades operacionais possuem vínculo com a clínica. Relações devem impedir associações entre entidades de clínicas distintas. A clínica enviada pelo navegador não é autorização.

Aplicar controles no servidor e políticas no banco. Processos com acesso ampliado exigem escopo explícito e auditoria. O Dev usa contexto de uma clínica por vez; administração global fica separada.

## Entidades conceituais

Clínica, usuário, vínculo de usuário, funções e escopo, profissional, paciente por clínica, responsável, disponibilidade, bloqueio, consulta, lista de espera, autorização de mensagens, tarefa, tentativa, conexão Google, evento sincronizado e registro de auditoria.

Este modelo é conceitual e não constitui esquema aprovado.

## Integridade e automação

- Proteger conflitos no banco, além da interface.
- Usar identificadores de operações e versões das consultas.
- Persistir tarefas junto da consulta para evitar gravações parciais.
- Controlar concorrência, repetição, expiração e recuperação de tarefas.
- Tratar resultado ambíguo do fornecedor antes de reenviar. Não prometer entrega exatamente uma vez quando o fornecedor não permite essa garantia.
- Validar autenticidade dos retornos e tratar callbacks repetidos.
- Falhas externas não bloqueiam a agenda; ficam visíveis e recuperáveis.

## Disponibilidade externa

Verificar ocupação do Google, respeitando fuso horário. A disponibilidade pode mudar entre consulta e gravação; não existe transação única com o Google. Política de conflitos, comportamento durante indisponibilidade e calendários consultados estão pendentes.

## Portabilidade

Separar integrações por adaptadores, versionar migrações, manter configurações fora do código e documentar exportação, implantação e restauração. Uso inicial online; operação offline não integra o escopo definido.

## Referências técnicas

- [Intervalos e restrições no PostgreSQL](https://www.postgresql.org/docs/current/rangetypes.html)
- [Criação de eventos Google](https://developers.google.com/workspace/calendar/api/guides/create-events)
- [Permissões Google Agenda](https://developers.google.com/workspace/calendar/api/auth)
- [WhatsApp e modelos de mensagem](https://www.twilio.com/docs/whatsapp/key-concepts)

Twilio é referência documental, não fornecedor contratado.
