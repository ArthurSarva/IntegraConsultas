# Requisitos funcionais

Status: requisitos acordados, salvo itens explicitamente marcados como propostas ou pendências.

## Plataforma e clínicas

- RF-01: Aplicação web responsiva para computador, tablet e celular.
- RF-02: Agenda oficial mantida no IntegraConsultas.
- RF-03: Suporte a múltiplas clínicas, com isolamento de pacientes, profissionais, consultas, usuários vinculados e configurações.
- RF-04: Um usuário pode pertencer a várias clínicas e acumular funções por vínculo.
- RF-05: Exibir a clínica ativa; validar o vínculo e as permissões no servidor em cada operação.
- RF-06: Autoagendamento será opcional por clínica em versão futura. Suas regras serão decididas nessa versão; não integra a implementação inicial.

## Perfis

| Perfil | Permissões acordadas |
|---|---|
| Dev | Cadastrar clínicas e administradores, vinculá-los às clínicas e acessar qualquer clínica mediante seleção explícita |
| Administrador de clínica | Acessar e cadastrar médicos, recepção e pacientes, gerenciar agendas, consultar relatórios e logs da própria clínica |
| Médico | Acessar a própria agenda e os pacientes vinculados aos seus atendimentos |
| Recepção | Agendar consultas, cadastrar e pesquisar pacientes e consultar suas consultas dentro da clínica vinculada |

- RF-07: O Dev escolhe uma clínica e visualiza seus dados separadamente. Todas as ações nesse contexto são vinculadas à clínica selecionada e auditadas.
- RF-08: Cadastro de clínicas e vinculação de administradores ficam na administração geral da plataforma.
- RF-09: Médico com função de recepção pode gerenciar somente a própria agenda, inclusive quando não possui recepção dedicada.
- RF-10: Acúmulo de funções não concede acesso automático a outras clínicas ou agendas de colegas.

## Agenda

- RF-11: Cadastrar pacientes, profissionais, disponibilidade e bloqueios.
- RF-12: Agendar, cancelar e reagendar consultas.
- RF-13: Estados: agendada, confirmada, concluída, cancelada e falta.
- RF-14: Duração padrão configurável por profissional por seleção de 15, 30, 45 ou 60 minutos. O profissional que realiza o agendamento pode escolher uma duração diferente para a consulta. Valores e limites dessas exceções ainda serão definidos.
- RF-15: Impedir sobreposição para o mesmo profissional, inclusive em operações simultâneas.
- RF-16: Manter lista de espera para aproveitar horários liberados.
- RF-17: Permitir encaixes somente a usuários autorizados e em horários livres, sem sobreposição. Disponibilizar caixa de seleção para substituir uma consulta preexistente, preservando seu histórico e atualizando seus lembretes e evento no Google. Substituição não autoriza manter duas consultas ativas no mesmo intervalo. Permissões e tratamento operacional da consulta substituída ainda serão detalhados.
- RF-18: Atender consultas presenciais e online, com endereço ou link correspondente.
- RF-19: Não incluir controle de salas e equipamentos no escopo inicial.
- RF-20: Paciente pode confirmar presença ou solicitar cancelamento pelo WhatsApp ou por link. Cancelar automaticamente quando a data da solicitação for anterior à véspera da consulta, considerando o fuso horário da clínica. Na véspera ou no dia da consulta, exigir aprovação. Exemplo: consulta na quinta-feira pode ser cancelada automaticamente até terça-feira; na quarta ou quinta, depende de aprovação. A solicitação pendente não cria um novo estado de consulta; fluxo, aprovadores e solicitações posteriores à consulta ainda serão definidos.
- RF-21: Cadastrar responsáveis e definir destinatário das mensagens, inclusive em telefones compartilhados.

## WhatsApp

- RF-22: Usar integração oficial e número a ser providenciado pela clínica.
- RF-23: Configurar antecedência dos lembretes e horários permitidos de envio.
- RF-24: Registrar autorização para mensagens e oferecer interrupção dos lembretes.
- RF-25: Acompanhar programação, envio, entrega e falhas. Aceitação pelo fornecedor não equivale a entrega.
- RF-26: Invalidar lembretes antigos em cancelamentos e reagendamentos.
- RF-27: Verificar estado, horário e destinatário atual da consulta antes do envio.
- RF-28: Repetir falhas transitórias com controle de duplicidade e encerrar tentativas após cancelamento ou horário da consulta.
- RF-29: Processar lembretes no servidor mesmo com navegador fechado.

## Google Agenda

- RF-30: Médico autoriza integração com sua conta Google sem fornecer senha ao sistema.
- RF-31: Criar evento ao agendar; atualizar ao reagendar; remover ao cancelar; transferir registro ao trocar de médico.
- RF-32: Compromissos externos bloqueiam disponibilidade usando apenas informação de ocupado, sem importar detalhes pessoais.
- RF-33: Exibir pendências e falhas, repetir sincronizações com segurança e evitar eventos duplicados.
- RF-34: Configurar vínculo de agenda por profissional e clínica.
- RF-37: Se o Google estiver indisponível, permitir agendamento com alerta de que a disponibilidade externa não foi verificada. Manter sincronização e atualização pendentes para nova tentativa após recuperação; não cancelar nem substituir automaticamente uma consulta diante de conflito externo.

Proposta inicial: publicar consultas do IntegraConsultas no Google; alterações diretas em eventos do Google não modificam consultas. Consulta de disponibilidade externa é um fluxo separado. Publicar apenas título genérico, horário e link autenticado, sem identificação do paciente por padrão.

## Relatórios

- RF-35: Consultas por período e profissional; confirmações, cancelamentos, faltas e falhas dos lembretes.
- RF-36: Administrador acessa logs de acesso e ações somente da clínica vinculada.

## Pendências

Consultas recorrentes, transições de estados, aprovadores de cancelamento, detalhes da substituição de consultas, limites de duração excepcional, elegibilidade da lista de espera, conflitos externos e acesso detalhado aos pacientes serão especificados antes da implementação correspondente. Autoagendamento fica para versão futura.
