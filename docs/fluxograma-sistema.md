# Fluxogramas do sistema

Status: documentação dos fluxos acordados; não representa funcionalidades implementadas.
Base: [requisitos funcionais](requisitos-funcionais.md). Decisões não resolvidas estão identificadas como pendentes.

## Leitura dos diagramas

Caixas representam ações; losangos, decisões. Pendências aparecem com a palavra **PENDENTE**, borda tracejada e fundo laranja. Alertas usam fundo amarelo. A cor complementa o texto, sem ser o único indicador. Explicações e limites funcionais permanecem abaixo dos diagramas. Continuação entre diagramas evita setas de retorno excessivamente longas.

## 1. Acesso e visão geral

```mermaid
flowchart TD
 A["Login"] --> B{"Autenticado?"}
 B -->|Não| X["Negar acesso"]
 B -->|Sim| C{"Dev?"}
 C -->|Sim| D{"Área"}
 D -->|Plataforma| E["Clínicas e administradores"]
 D -->|Clínica| F["Selecionar clínica"]
 C -->|Não| G["Selecionar vínculo autorizado"]
 F --> H["Exibir clínica ativa"]
 G --> H
 H --> I{"Permissão e escopo válidos?"}
 I -->|Não| J["Negar e registrar"]
 I -->|Sim| K["Executar e auditar"]
 classDef fim fill:#dcfce7,stroke:#166534,color:#14532d;
 class E,K fim;
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
 A["Pesquisar paciente"] --> B{"Existe na clínica?"}
 B -->|Não| C["Cadastrar dados mínimos"]
 B -->|Sim| D["Selecionar paciente"]
 C --> D
 D --> E{"Responsável ou contato compartilhado?"}
 E -->|Sim| F["Definir responsável e destinatário"]
 E -->|Não| G["Definir contato do paciente"]
 F --> H["Registrar autorização de mensagens"]
 G --> H
 H --> I["Disponível para agendamento"]
```

Não pesquisar pacientes de outras clínicas. Critérios de identificação, representação de menores e acesso detalhado ainda precisam ser especificados.

## 3. Agendamento, encaixe e substituição

```mermaid
flowchart TD
 A["Paciente e médico"] --> B["Data, horário e modalidade"]
 B --> C["Duração: 15, 30, 45 ou 60 min"]
 C --> D{"Conflito interno?"}
 D -->|Não| E["Verificar bloqueios e Google"]
 D -->|Sim| F{"Substituição autorizada e selecionada?"}
 F -->|Não| G["Escolher outro horário"]
 F -->|Sim| H["Identificar consulta anterior"]
 H --> E
 E --> I{"Disponibilidade externa"}
 I -->|Ocupado| G
 I -->|Livre| J["Continuar para gravação"]
 I -->|Indisponível| K["Alertar e marcar pendência"]
 K --> J
 classDef alerta fill:#fef3c7,stroke:#92400e,color:#78350f;
 class K alerta;
```

### 3.1. Gravação e substituição

```mermaid
flowchart TD
 A["Validar novamente no banco"] --> B{"Pode gravar?"}
 B -->|Não| C["Escolher outro horário"]
 B -->|Sim| D{"Há substituição?"}
 D -->|Sim| E["Preservar histórico anterior"]
 E --> F["Gravar substituição e tarefas"]
 D -->|Não| G["Gravar consulta e tarefas"]
 F --> H["Consulta agendada"]
 G --> H
 H --> I["Auditar"]
 I --> J["Processar integrações"]
 classDef pendente fill:#fff7ed,stroke:#c2410c,stroke-dasharray:5 5,color:#9a3412;
 P["PENDENTE: destino e aviso da consulta anterior"]:::pendente
 E -.-> P
```

Substituição libera o horário da consulta anterior e cria a nova sem duas consultas ativas sobrepostas. Deve preservar histórico, invalidar lembretes antigos e atualizar eventos. Recepção e administrador podem substituir dentro do escopo. Estado final da consulta substituída e notificações permanecem pendentes. Não substituir compromissos pessoais do Google nem ignorar outros bloqueios.

A etapa de validação final protege contra concorrência interna; não garante disponibilidade externa imutável entre a consulta ao Google e a gravação.

## 4. Confirmação e cancelamento pelo paciente

```mermaid
flowchart TD
 A["Validar resposta do paciente"] --> B{"Válida?"}
 B -->|Não| C["Informar impedimento"]
 B -->|Sim| D{"Ação"}
 D -->|Confirmar| E["Registrar confirmada"]
 D -->|Cancelar| F{"Data local da solicitação"}
 F -->|Antes da véspera| G["Cancelar"]
 F -->|Véspera ou dia| H["Solicitação pendente"]
 H --> I{"Recepção ou administrador aprova?"}
 I -->|Sim| G
 I -->|Não| J["Manter consulta"]
 F -->|Após o dia| P["PENDENTE: tratamento"] 
 G --> K["Invalidar lembretes e remover evento"]
 K --> L["Liberar horário à lista de espera"]
 E --> M["Auditar"]
 J --> M
 L --> M
 classDef pendente fill:#fff7ed,stroke:#c2410c,stroke-dasharray:5 5,color:#9a3412;
 class P pendente;
```

Exemplo: consulta na quinta-feira permite cancelamento automático até terça-feira. Quarta e quinta exigem aprovação. Solicitação pendente é um registro separado, não um novo estado da consulta. Notificações e regras para consultas concluídas ou com falta ainda serão detalhadas.

## 5. Reagendamento e encerramento

```mermaid
flowchart TD
 A["Validar clínica e permissão"] --> B{"Ação"}
 B -->|Reagendar| C["Verificar novo intervalo"]
 C --> D["Gravar horário e invalidar confirmação antiga"]
 D --> E["Exigir nova confirmação"]
 E --> F["Reavaliar lembrete e atualizar Google"]
 B -->|Concluir| G["Recepção ou administrador: concluída"]
 B -->|Ausência| H["Recepção ou administrador: falta"]
 B -->|Cancelar pela equipe| P["PENDENTE: fluxo detalhado"]
 F --> I["Auditar"]
 G --> I
 H --> I
 P -.-> I
 classDef pendente fill:#fff7ed,stroke:#c2410c,stroke-dasharray:5 5,color:#9a3412;
 class P pendente;
```

Concluída e falta não serão definidas automaticamente pela simples passagem do horário. Recepção e administrador registram conclusão ou falta. Reagendamento exige nova confirmação. Transições detalhadas permanecem pendentes.

## 6. Lembretes em segundo plano

```mermaid
flowchart TD
 A["Avaliar consulta"] --> B{"Antecedência ≥ 24h e envio ainda não passou?"}
 B -->|Não| C["Não programar"]
 B -->|Sim| D["Um lembrete: 8h da véspera"]
 D --> E["Aguardar horário"]
 E --> F{"Consulta, tarefa e destinatário válidos?"}
 F -->|Não| G["Invalidar"]
 F -->|Sim| H{"Autorização e prazo válidos?"}
 H -->|Não| G
 H -->|Sim| I["Enviar WhatsApp"]
 I --> J{"Resultado"}
 J -->|Aceito| K["Aguardar retorno de entrega"]
 K --> L["Validar retorno e registrar"]
 J -->|Falha definitiva| M["Exibir falha"]
 J -->|Transitório ou ambíguo| P["PENDENTE: detalhar repetição e conciliação"]
 classDef pendente fill:#fff7ed,stroke:#c2410c,stroke-dasharray:5 5,color:#9a3412;
 class P pendente;
```

Programar somente um lembrete às 8h da véspera. Não enviar para agendamentos com menos de 24 horas nem criar envio tardio quando o horário previsto já passou. Distinguir envio inicial tardio de repetição após falha: a política de repetição ainda está pendente. Interromper tentativas após cancelamento ou horário da consulta. Mensagem aceita não significa entregue. Consulta concluída, com falta ou tarefa de versão anterior não deve disparar lembrete. Políticas de repetição, ambiguidades e alertas serão detalhadas. Funcionamento independe do navegador.

## 7. Google Agenda

```mermaid
flowchart TD
 A["Médico autoriza Google"] --> B["Vincular calendário à clínica"]
 B --> C["Consulta gera tarefa"]
 C --> D["Conferir versão e evento"]
 D --> E["Criar, atualizar, remover ou transferir"]
 E --> F{"Resultado"}
 F -->|Sucesso| G["Registrar sincronização"]
 F -->|Falha temporária| H["Manter pendente"]
 H --> I["Continuar no fluxo de recuperação"]
 F -->|Revogado| J["Solicitar reconexão"]
 classDef alerta fill:#fef3c7,stroke:#92400e,color:#78350f;
 class H,J alerta;
```

### 7.1. Recuperação após indisponibilidade

```mermaid
flowchart TD
 A["Google recuperado"] --> B["Consultar ocupação externa"]
 B --> C["Desconsiderar o próprio evento"]
 C --> D{"Conflito?"}
 D -->|Não| E["Retomar sincronização"]
 D -->|Sim| F["Preservar consulta e sinalizar"]
 F --> G["Exigir outro horário"]
 G --> H["Reagendar e exigir confirmação"]
 H --> E
 E --> I["Auditar resultado"]
 classDef alerta fill:#fef3c7,stroke:#92400e,color:#78350f;
 class F alerta;
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
