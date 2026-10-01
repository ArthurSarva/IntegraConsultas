# Fluxogramas do sistema

Status: documentação dos fluxos acordados; não representa funcionalidades implementadas.
Base: [requisitos funcionais](requisitos-funcionais.md). Decisões não resolvidas estão identificadas como pendentes.

## 1. Acesso e visão geral

```mermaid
flowchart TD
    A["Abrir aplicação web"] --> B["Autenticar usuário"]
    B --> C{"Autenticação válida?"}
    C -->|Não| D["Negar acesso"]
    C -->|Sim| E{"Perfil Dev?"}
    E -->|Sim| F{"Área desejada"}
    F -->|Plataforma| G["Cadastrar clínicas e administradores; vincular"]
    F -->|Clínica| H["Selecionar uma clínica"]
    E -->|Não| I["Selecionar clínica entre vínculos autorizados"]
    H --> J["Exibir clínica ativa"]
    I --> J
    J --> K["Validar funções e escopo em cada operação"]
    K --> L{"Operação autorizada?"}
    L -->|Não| M["Negar operação e registrar ocorrência"]
    L -->|Sim| N["Executar no contexto da clínica"]
    N --> O["Pacientes, agenda, relatórios ou administração"]
    O --> P["Registrar acessos e ações relevantes"]
    P --> K
```

| Perfil | Áreas permitidas |
|---|---|
| Dev | Administração global ou dados de uma clínica selecionada |
| Administrador | Profissionais, recepção, pacientes, agendas, relatórios e logs da própria clínica |
| Médico | Própria agenda e pacientes dos próprios atendimentos |
| Recepção | Cadastro, edição e pesquisa de pacientes, consultas, agendamento e bloqueios da clínica |
| Médico com recepção | Gestão somente da própria agenda |

Seleção de clínica não substitui autorização no servidor. Trocar de clínica exige novo contexto e validação. Dados não são agregados entre clínicas na visão operacional do Dev.

## 2. Pacientes e responsáveis

```mermaid
flowchart TD
    A["Usuário autorizado na clínica"] --> B["Pesquisar paciente"]
    B --> C{"Paciente cadastrado nesta clínica?"}
    C -->|Sim| D["Selecionar cadastro autorizado"]
    C -->|Não| E["Cadastrar dados mínimos necessários"]
    E --> D
    D --> F{"Há responsável ou contato compartilhado?"}
    F -->|Sim| G["Cadastrar responsável e definir destinatário"]
    F -->|Não| H["Definir contato do paciente"]
    G --> I["Registrar preferência e autorização de mensagens"]
    H --> I
    I --> J["Disponibilizar paciente para agendamento"]
```

Não pesquisar pacientes de outras clínicas. Critérios de identificação, representação de menores e acesso detalhado ainda precisam ser especificados.

## 3. Agendamento, encaixe e substituição

```mermaid
flowchart TD
    A["Usuário autorizado inicia agendamento"] --> B["Selecionar paciente e profissional da clínica"]
    B --> C["Informar data, horário e modalidade"]
    C --> D["Duração padrão: 15, 30, 45 ou 60 minutos"]
    D --> E{"Profissional que agenda escolhe exceção?"}
    E -->|Sim| F["Escolher 15, 30, 45 ou 60 minutos para a consulta"]
    E -->|Não| G["Manter duração padrão"]
    F --> H["Verificar disponibilidade e conflitos internos"]
    G --> H
    H --> I{"Conflito com consulta existente?"}
    I -->|Sim| J{"Recepção ou administrador selecionou substituir?"}
    J -->|Não| K["Escolher outro horário; sem sobreposição"]
    K --> C
    J -->|Sim| L["Identificar consulta a substituir e preservar histórico"]
    I -->|Não| M["Encaixe permitido apenas em intervalo livre"]
    L --> N["Verificar demais bloqueios e disponibilidade Google"]
    M --> N
    N --> O{"Disponibilidade externa"}
    O -->|Ocupado| K
    O -->|Livre| P["Validar novamente integridade no banco"]
    O -->|Google indisponível| Q["Exibir alerta; marcar verificação e atualização pendentes"]
    Q --> P
    P --> R{"Validação final permite operação?"}
    R -->|Não| K
    R -->|Sim| S["Gravar consulta e tarefas na mesma transação"]
    S --> T["Estado: agendada; registrar auditoria"]
    T --> U["Processar lembretes e integração Google"]
```

Substituição libera o horário da consulta anterior e cria a nova sem duas consultas ativas sobrepostas. Deve preservar histórico, invalidar lembretes antigos e atualizar eventos. Recepção e administrador podem substituir dentro do escopo. Estado final da consulta substituída e notificações permanecem pendentes. Não substituir compromissos pessoais do Google nem ignorar outros bloqueios.

A etapa de validação final protege contra concorrência interna; não garante disponibilidade externa imutável entre a consulta ao Google e a gravação.

## 4. Confirmação e cancelamento pelo paciente

```mermaid
flowchart TD
    A["Paciente responde pelo WhatsApp ou link"] --> B["Validar identidade ou vínculo seguro da ação com a consulta"]
    B --> C{"Ação válida para consulta atual?"}
    C -->|Não| D["Informar impedimento; preservar dados"]
    C -->|Sim| E{"Ação"}
    E -->|Confirmar| F["Registrar confirmação e auditoria"]
    F --> G["Estado: confirmada"]
    E -->|Cancelar| H["Comparar datas no fuso da clínica"]
    H --> I{"Data da solicitação"}
    I -->|Antes da véspera| J["Cancelar imediatamente"]
    I -->|Na véspera ou no dia| K["Registrar solicitação pendente"]
    I -->|Depois do dia| L["Tratamento pendente de definição"]
    K --> M["Encaminhar à recepção ou administrador autorizado"]
    M --> N{"Decisão"}
    N -->|Aprovar| J
    N -->|Não aprovar| O["Manter consulta; registrar decisão"]
    J --> P["Estado: cancelada; registrar auditoria"]
    P --> Q["Invalidar lembretes e solicitar remoção do evento Google"]
    Q --> R["Disponibilizar horário para lista de espera"]
```

Exemplo: consulta na quinta-feira permite cancelamento automático até terça-feira. Quarta e quinta exigem aprovação. Solicitação pendente é um registro separado, não um novo estado da consulta. Notificações e regras para consultas concluídas ou com falta ainda serão detalhadas.

## 5. Reagendamento e encerramento

```mermaid
flowchart TD
    A["Consulta existente"] --> B["Validar clínica, escopo e ação"]
    B --> C{"Ação autorizada"}
    C -->|Reagendar| D["Escolher novo intervalo e verificar disponibilidade"]
    D --> E["Aplicar verificações do fluxo de agendamento"]
    E --> F["Persistir novo horário; invalidar confirmação e tarefas antigas"]
    F --> G["Exigir nova confirmação; avaliar lembrete e atualizar Google"]
    C -->|Concluir| H["Recepção ou administrador registra concluída"]
    C -->|Registrar ausência| I["Recepção ou administrador registra falta"]
    C -->|Cancelar pela equipe| J["Fluxo e permissões pendentes"]
    G --> K["Auditar alteração"]
    H --> K
    I --> K
    J --> K
```

Concluída e falta não serão definidas automaticamente pela simples passagem do horário. Recepção e administrador registram conclusão ou falta. Reagendamento exige nova confirmação. Transições detalhadas permanecem pendentes.

## 6. Lembretes em segundo plano

```mermaid
flowchart TD
    A["Avaliar lembrete da consulta atual"] --> A1{"Agendada com pelo menos 24h e antes ou às 8h da véspera?"}
    A1 -->|Não| E["Não enviar lembrete tardio"]
    A1 -->|Sim| A2["Persistir um lembrete para 8h da véspera no fuso da clínica"]
    A2 --> B["Aguardar horário de envio"]
    B --> C["Carregar consulta atual no contexto da clínica"]
    C --> D{"Tarefa e destinatário ainda válidos?"}
    D -->|Não| E["Invalidar ou não programar; não enviar"]
    D -->|Sim| F["Verificar autorização, expiração e repetição"]
    F --> G{"Pode enviar?"}
    G -->|Não| E
    G -->|Sim| H["Enviar por API oficial do WhatsApp"]
    H --> I{"Resultado"}
    I -->|Aceito| J["Registrar enviado; aguardar retorno"]
    I -->|Falha transitória| K["Programar tentativa dentro do prazo"]
    I -->|Resultado ambíguo| L["Verificar resultado antes de reenviar"]
    I -->|Falha definitiva| M["Registrar falha e exibir à equipe"]
    K --> B
    L --> M
    J --> N["Validar retorno do fornecedor e evitar processamento duplicado"]
    N --> O["Atualizar entrega ou falha; auditar"]
```

Programar somente um lembrete às 8h da véspera. Não enviar para agendamentos com menos de 24 horas nem criar envio tardio quando o horário previsto já passou. Distinguir envio inicial tardio de repetição após falha: a política de repetição ainda está pendente. Interromper tentativas após cancelamento ou horário da consulta. Mensagem aceita não significa entregue. Consulta concluída, com falta ou tarefa de versão anterior não deve disparar lembrete. Políticas de repetição, ambiguidades e alertas serão detalhadas. Funcionamento independe do navegador.

## 7. Google Agenda

```mermaid
flowchart TD
    A["Médico autoriza conta Google via OAuth"] --> B["Vincular calendário ao profissional e à clínica"]
    B --> C["Consulta criada, alterada ou cancelada"]
    C --> D["Persistir tarefa de sincronização"]
    D --> E["Conferir versão atual e vínculo do evento"]
    E --> F["Criar, atualizar, remover ou transferir evento"]
    F --> G{"Resultado"}
    G -->|Sucesso| H["Guardar vínculo; marcar sincronizado"]
    G -->|Falha temporária| I["Manter pendente e repetir com segurança"]
    G -->|Autorização revogada| J["Solicitar reconexão e manter pendência"]
    I --> R["Após recuperação, consultar ocupação externa sem considerar o próprio evento"]
    R --> S{"Há conflito?"}
    S -->|Não| E
    S -->|Sim| T["Preservar consulta e sinalizar conflito"]
    T --> U["Exigir escolha de outro horário"]
    U --> V["Aplicar fluxo de reagendamento e exigir nova confirmação"]
    V --> E
    J --> A
    H --> K["Registrar auditoria e situação da integração"]
```

Consulta de ocupação externa é um fluxo separado da publicação de eventos. Após indisponibilidade, retomar verificação e atualização; sinalizar conflitos e exigir outro horário, preservando a consulta sem apagá-la automaticamente. Conflito não constitui um sexto estado da consulta. Excluir eventos do próprio sistema da interpretação de conflito consigo mesmos.

Proposta inicial: alterações manuais no Google não alteram consultas do IntegraConsultas. Publicar título genérico, horário e link autenticado, sem dados identificáveis do paciente por padrão.

## 8. Escopo futuro e pendências

- Autoagendamento: versão futura, opcional por clínica; regras ainda não definidas.
- Lista de espera: cadastro e aproveitamento de vagas acordados; ordem de contato acordada, mas significado operacional, elegibilidade e reserva pendentes.
- Consultas recorrentes: inclusão ainda não decidida.
- Fluxos não aprovados não são inferidos como permissões implementáveis.
- Segurança, isolamento entre clínicas, integridade, auditoria e restauração de backups continuam condições obrigatórias de lançamento.

Recepção e administrador podem editar pacientes e bloquear horários no escopo autorizado. Exportação é exclusiva do administrador. Forma do link online continua para decisão posterior.

## Rastreabilidade

| Diagramas | Requisitos |
|---|---|
| Acesso | RF-01 a RF-10, RF-36, RF-40, RF-41 |
| Pacientes | RF-11, RF-21, RF-24 |
| Agendamento | RF-12 a RF-19, RF-32, RF-37 |
| Confirmação e cancelamento | RF-13, RF-16, RF-20, RF-26 |
| Reagendamento e encerramento | RF-12, RF-13, RF-26, RF-31, RF-38, RF-39 |
| WhatsApp | RF-22 a RF-29 |
| Google | RF-30 a RF-34, RF-37 |
