# Matriz de permissões

Status: especificação documental para revisão. Consolida os [requisitos funcionais](requisitos-funcionais.md) e o [modelo de dados](modelo-dados.md); não implementa autorização.

## 1. Legenda

- **Clínica**: permitido somente dentro da clínica ativa e do vínculo autorizado.
- **Próprio**: permitido somente na agenda do médico vinculado.
- **Pacientes próprios**: pacientes vinculados aos atendimentos do médico; campos e histórico acessíveis ainda precisam de detalhamento.
- **Selecionada**: Dev deve selecionar explicitamente a clínica.
- **Global**: operação de plataforma.
- **Não**: perfil não possui essa permissão isoladamente.
- **Pendente**: não há regra aprovada suficiente; negar até definição.
- Toda permissão pressupõe autenticação, vínculo ativo, recurso correto e validação no servidor.
- As tabelas descrevem perfis isolados. Administrador e Dev não são atribuídos pelo simples acúmulo de médico e recepção.

## 2. Administração de usuários e clínicas

| Ação | Dev | Administrador | Médico | Recepção | Médico + recepção |
|---|---|---|---|---|---|
| Cadastrar clínica | Global | Não | Não | Não | Não |
| Cadastrar administrador | Global | Não | Não | Não | Não |
| Vincular administrador à clínica | Global | Não | Não | Não | Não |
| Selecionar clínica | Qualquer clínica | Vínculos autorizados | Vínculos autorizados | Vínculos autorizados | Vínculos autorizados |
| Cadastrar médico | Pendente | Clínica | Não | Não | Não |
| Cadastrar recepção | Pendente | Clínica | Não | Não | Não |
| Consultar médicos e usuários | Selecionada | Clínica | Pendente | Pendente | Pendente |
| Alterar funções ou desativar usuários | Pendente | Pendente | Não | Não | Não |
| Conceder perfil Dev | Pendente | Não | Não | Não | Não |

Cadastrar médico ou recepção não equivale a conceder administração, Dev ou acesso a outra clínica. Convites, recuperação de conta, desligamento e alteração de funções serão especificados separadamente.

## 3. Pacientes e agenda

| Ação | Dev | Administrador | Médico | Recepção | Médico + recepção |
|---|---|---|---|---|---|
| Consultar agenda | Selecionada | Clínica | Próprio | Clínica | Próprio |
| Consultar paciente | Selecionada | Clínica | Pacientes próprios | Clínica | Pacientes próprios |
| Pesquisar paciente e consultas | Selecionada | Clínica | Pacientes próprios | Clínica | Pacientes próprios |
| Cadastrar paciente | Pendente | Clínica | Não | Clínica | Próprio, para agendamento |
| Editar cadastro do paciente | Pendente | Clínica | Não | Clínica | Pendente: cadastro compartilhado |
| Agendar consulta | Pendente | Clínica | Não | Clínica | Próprio |
| Reagendar consulta | Pendente | Clínica | Não | Clínica | Próprio |
| Substituir consulta existente | Pendente | Clínica | Não | Clínica | Próprio |
| Aprovar cancelamento do paciente | Pendente | Clínica | Não | Clínica | Próprio |
| Registrar concluída ou falta | Pendente | Clínica | Não | Clínica | Próprio |
| Bloquear horários | Pendente | Clínica | Não | Clínica | Próprio |
| Definir duração padrão | Pendente | Pendente | Próprio | Pendente | Próprio |
| Escolher duração diferente ao agendar | Pendente | Pendente | Não | Pendente | Próprio |
| Cancelar diretamente pela equipe | Pendente | Pendente | Não | Pendente | Pendente |
| Gerenciar lista de espera | Pendente | Pendente | Não | Pendente | Pendente |

O médico isolado consulta agenda e pacientes. A função adicional de recepção permite gerir a própria agenda, mantendo as restrições das ações atribuídas à recepção. Nenhuma coluna permite modificar consulta pertencente a outra clínica.

Durações permitidas: 15, 30, 45 e 60 minutos. A escolha específica pelo profissional que agenda foi aprovada; não estender automaticamente essa exceção à recepção ou ao administrador.

Aprovar cancelamento pendente e cancelar diretamente pela equipe são ações diferentes. A segunda ainda depende de definição do fluxo.

O Dev possui acesso aos dados da clínica selecionada; ações operacionais de escrita não explicitadas permanecem pendentes. Isso não remove o acesso administrativo global já acordado.

### Pacientes compartilhados por médicos da mesma clínica

Um cadastro pode estar vinculado a atendimentos de vários médicos. Alterar esse cadastro produz efeito compartilhado. Precisamos definir se médico com recepção pode editar todo o cadastro ou apenas contato/dados de seu atendimento. Até essa decisão, não conceder edição ampla.

Também permanecem pendentes os campos e períodos de histórico acessíveis ao médico, inclusive quando deixa de atender o paciente. Cadastro de paciente novo para agendamento próprio não permite pesquisar pacientes alheios ao escopo.

## 4. Comunicação, relatórios e dados

| Ação | Dev | Administrador | Médico | Recepção | Médico + recepção |
|---|---|---|---|---|---|
| Consultar relatórios da clínica | Selecionada | Clínica | Pendente | Pendente | Pendente |
| Consultar logs da clínica | Selecionada | Clínica | Não | Não | Não |
| Exportar dados | Não | Clínica | Não | Não | Não |
| Alterar ou apagar auditoria | Não | Não | Não | Não | Não |
| Autorizar a própria conta Google | Conta própria | Conta própria se médico | Conta própria | Não, sem função médica | Conta própria |
| Conectar Google em nome de outro médico | Não | Não | Não | Não | Não |
| Configurar WhatsApp da clínica | Pendente | Pendente | Não | Não | Não |
| Consultar falhas de lembretes | Selecionada | Clínica | Pendente | Pendente | Pendente |
| Reenviar mensagens manualmente | Pendente | Pendente | Não | Pendente | Pendente |

A exportação é exclusiva do administrador com vínculo na clínica. Se um Dev tiver também função de administrador, só pode exportar por esse vínculo e contexto autorizado; o perfil Dev isolado não concede exportação.

Autorizar Google não significa poder editar todas as consultas da clínica nem abrir tokens. Segredos das integrações não são exibidos a usuários.

## 5. Ações do paciente e do responsável

Acesso por WhatsApp ou link é limitado à consulta, finalidade e versão validadas; não concede sessão administrativa.

| Ação | Condição |
|---|---|
| Confirmar | Consulta e ação válidas para a versão atual |
| Cancelar automaticamente | Data local da solicitação anterior à véspera |
| Solicitar cancelamento | Na véspera ou dia; recepção/administrador decide |
| Abrir outra consulta | Negado sem autorização específica |
| Usar link anterior ao reagendamento | Negado; nova confirmação exigida |
| Autoagendar | Fora da versão inicial |
| Agir como responsável | Vínculo e representação validados; detalhes pendentes |

Links não expõem dados pessoais na URL; resposta autenticada do fornecedor não basta para associar um telefone compartilhado ao paciente errado.

## 6. Decisão de autorização

Para cada ação:

1. Identificar usuário ou serviço e validar sessão.
2. Resolver clínica ativa no servidor; não confiar somente em clinic_id recebido.
3. Verificar vínculo ativo ou capacidade Dev com clínica explicitamente selecionada.
4. Carregar somente recurso autorizado e verificar clínica.
5. Avaliar ação, função, escopo próprio e restrições especiais.
6. Conferir versão e estado quando a operação altera agenda.
7. Executar transação e registrar auditoria.
8. Negar ações sem regra aprovada, sem revelar dados de outro contexto.

Filtros, relatórios, totais, buscas e exportações obedecem à mesma política. Ocultar botões não substitui autorização na API ou no banco.

### Acúmulo de funções

- Médico + recepção: agenda própria, inclusive substituição, aprovação, conclusão e bloqueios.
- Médico em A e recepção em B: não transportar função de B para A.
- Administrador em A e médico em B: acesso amplo apenas em A.
- Dev: clínica selecionada delimita operações clínicas; área global permanece separada.
- Outras combinações, especialmente administrador + médico, terão precedência detalhada antes da implementação; não usar união ingênua para contornar escopo.

## 7. Disponibilidade global sem exposição de dados

O mesmo médico não pode ter consultas agendadas ou confirmadas sobrepostas entre clínicas.

A rotina interna global pode responder apenas ocupado/livre ao fluxo autorizado, sem revelar clínica de origem, paciente, consulta ou detalhes de evento. Usuários comuns não leem diretamente registros globais de ocupação.

Um conflito em B não autoriza a recepção de A a abrir, cancelar ou substituir a consulta de B. Indisponibilidade do Google permite alerta e pendência, mas não elimina verificações internas de ocupação global.

Detalhes da identificação única do médico e permissões do processo interno permanecem propostas técnicas no modelo.

## 8. Processos automáticos

| Processo | Escopo necessário | Restrições |
|---|---|---|
| Lembretes | Consulta, contato, autorização e configuração da clínica da tarefa | Verificar versão, prazo, destinatário e autorização antes do envio |
| Google | Consulta, conexão e evento do médico/clínica | Não copiar dados de pacientes por padrão; proteger tokens |
| Verificação de ocupação | Identidade do médico e intervalo | Resposta mínima; sem acesso comum a dados de outras clínicas |
| Auditoria | Acrescentar registro do evento autorizado | Sem edição comum, sem segredos |
| Exportação | Administrador e clínica autorizados | Revalidar vínculo antes de processar e entregar |
| Backup e recuperação | Identidade técnica específica | Acesso separado de perfis de usuários; restauração testada |

Execução em segundo plano não herda acesso irrestrito do Dev. Cada tarefa carrega contexto, valida vínculos de recursos e usa privilégio mínimo.

## 9. Exemplos para critérios de aceite

| ID | Cenário | Resultado esperado |
|---|---|---|
| PA-01 | Daniela, recepção de A, busca paciente de B por ID | Negar sem revelar o cadastro |
| PA-02 | Arthur, recepção de B, agenda médico de B | Permitir se horário e demais regras válidos |
| PA-03 | Médico consulta agenda de colega | Negar |
| PA-04 | Médico com recepção substitui consulta própria | Permitir; cancelar anterior atomicamente |
| PA-05 | Médico com recepção bloqueia agenda de colega | Negar |
| PA-06 | Recepção aprova cancelamento da própria clínica | Permitir no escopo autorizado |
| PA-07 | Recepção exporta dados | Negar |
| PA-08 | Administrador de A exporta dados de A | Permitir e auditar |
| PA-09 | Administrador de A exporta dados de B | Negar |
| PA-10 | Dev seleciona A e consulta recurso de B sem trocar contexto | Negar |
| PA-11 | Dev isolado tenta exportar | Negar |
| PA-12 | Médico tem consulta confirmada em B; recepção tenta agendar em A no mesmo intervalo | Impedir; informar apenas indisponibilidade |
| PA-13 | Paciente usa link de confirmação anterior ao reagendamento | Negar |
| PA-14 | Tarefa de lembrete aponta contato de outra clínica | Não enviar; registrar falha de integridade |
| PA-15 | Vínculo revogado com sessão ainda aberta | Negar nova ação |
| PA-16 | Administrador tenta editar auditoria | Negar |
| PA-17 | Duas clínicas tentam agendar simultaneamente o mesmo médico | Uma operação é recusada por conflito; sem vazamento |
| PA-18 | Alteração do clinic_id no navegador | Negar operação não autorizada |
| PA-19 | Confirmação muda agendada para confirmada | Manter ocupação do horário |
| PA-20 | Ação pendente sem regra definida | Negar até aprovação da política |

Estes são cenários de testes futuros, não testes já executados.

## 10. Pendências

- Escritas operacionais do Dev além da administração global definida.
- Convites, desativação, alterações de função e concessão do perfil Dev.
- Precedência de combinações com administrador.
- Edição de pacientes compartilhados pelo médico com recepção.
- Campos/histórico acessíveis ao médico.
- Duração específica quando agendamento é feito por recepção/administrador.
- Cancelamento direto pela equipe e transições de estado.
- Gestão da lista de espera, integrações e falhas.
- Política de exportação, retenção e incidentes.

A implementação deverá resolver as pendências ou manter a respectiva ação negada. A matriz não cria permissões implicitamente.
