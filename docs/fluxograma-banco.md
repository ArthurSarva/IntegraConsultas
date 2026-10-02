# Diagramas e fluxogramas do banco

Data: 02/10/2026. Proposta para revisão; não representa banco implementado. Leia junto com [arquitetura do banco](arquitetura-banco.md) e [modelo lógico](modelo-dados.md).

Diagramas divididos por domínio para facilitar leitura. Cardinalidades mostram estrutura, não permissões. clinic_id é obrigatório nos registros operacionais mesmo quando omitido na figura.

## 1. Arquitetura e limites de acesso

```mermaid
flowchart TB
    WEB["Aplicação web"] --> AUTH["Supabase Auth"]
    WEB --> SERVER["Servidor: identidade, clínica e ação"]
    AUTH --> SERVER
    subgraph DB["PostgreSQL por ambiente"]
        APP["app: cadastros e agenda com RLS"]
        PRIV["private: identidade médica e ocupação"]
        INT["integration: tarefas e integrações"]
        AUD["audit: acessos e ações"]
    end
    SERVER --> APP
    SERVER --> ROUTINE["Rotina autorizada de ocupação"]
    ROUTINE --> PRIV
    APP --> INT
    SERVER --> AUD
    WORKER["Processador com escopo da tarefa"] --> INT
    WORKER --> APP
    WORKER --> EXT["WhatsApp e Google"]
    WORKER --> AUD
    DB --> BACKUP["Backup externo criptografado"]
```

As setas representam dependências e operações autorizadas, não grants. O processador revalida recursos da clínica; não recebe acesso irrestrito por causa da automação. A fronteira transacional está dentro do PostgreSQL.

## 2. Identidade e clínicas

```mermaid
erDiagram
    AUTH_USER ||--o| USER : identifica
    USER ||--o{ MEMBERSHIP : possui
    CLINIC ||--o{ MEMBERSHIP : recebe
    MEMBERSHIP ||--o{ ROLE_ASSIGNMENT : acumula
    MEMBERSHIP ||--o| PROFESSIONAL : representa
    USER ||--o| PHYSICIAN_IDENTITY : associa
    PHYSICIAN_IDENTITY ||--o{ PROFESSIONAL : unifica
```

AUTH_USER pertence ao Supabase; USER é a identidade da aplicação. Um usuário possui vínculos independentes. PHYSICIAN_IDENTITY é privada e exige verificação/deduplicação; email e nome não comprovam identidade médica única.

## 3. Pacientes e agenda

```mermaid
erDiagram
    CLINIC ||--o{ PATIENT : cadastra
    PATIENT ||--o{ PATIENT_RESPONSIBLE : possui
    RESPONSIBLE ||--o{ PATIENT_RESPONSIBLE : representa
    PATIENT ||--o{ CONTACT : utiliza
    RESPONSIBLE o|--o{ CONTACT : participa
    CONTACT ||--o{ MESSAGE_AUTHORIZATION : autoriza
    PATIENT ||--o{ APPOINTMENT : agenda
    PROFESSIONAL ||--o{ APPOINTMENT : atende
    PROFESSIONAL ||--o{ AVAILABILITY : oferece
    PROFESSIONAL ||--o{ BLOCK : restringe
    APPOINTMENT ||--o{ APPOINTMENT_HISTORY : registra
    APPOINTMENT ||--o{ CONFIRMATION : recebe
    APPOINTMENT ||--o{ CANCELLATION_REQUEST : recebe
```

Paciente, responsável, contato e consulta pertencem à mesma clínica. Uma solicitação de cancelamento não altera o estado até ser decidida.

## 4. Ocupação e processamento

```mermaid
erDiagram
    PHYSICIAN_IDENTITY ||--o{ PHYSICIAN_OCCUPANCY : reserva
    APPOINTMENT ||--o| PHYSICIAN_OCCUPANCY : ocupa
    APPOINTMENT ||--o{ ACTION_TOKEN : protege
    APPOINTMENT ||--o{ TASK : gera
    APPOINTMENT ||--o{ REMINDER : programa
    CONTACT ||--o{ REMINDER : recebe
    REMINDER ||--o{ MESSAGE_ATTEMPT : registra
    APPOINTMENT ||--o{ CALENDAR_EVENT : sincroniza
    CALENDAR_BINDING ||--o{ CALENDAR_EVENT : publica
    APPOINTMENT ||--o{ EXTERNAL_CONFLICT : sinaliza
```

Consulta agendada ou confirmada tem uma reserva ativa. Outros estados não mantêm reserva. TASK referencia versão; confirmação, tokens e tarefas antigas são invalidados no reagendamento. Configurações completas de integração estão no modelo lógico.

## 5. Criar agendamento

```mermaid
flowchart TD
    A["Receber pedido"] --> B["Validar identidade, clínica, função e escopo"]
    B --> C["Validar paciente, profissional e duração"]
    C --> D{"Google disponível?"}
    D -- Sim --> E{"Ocupação externa livre?"}
    E -- Não --> X["Recusar horário"]
    E -- Sim --> T["Iniciar transação"]
    D -- Não --> P["Preparar alerta e sincronização pendente"]
    P --> T
    T --> L["Aplicar locks e revalidar agenda interna"]
    L --> V{"Disponibilidade e bloqueios válidos?"}
    V -- Não --> R["Rollback e resposta genérica"]
    V -- Sim --> O["Inserir consulta e reserva global"]
    O --> Q{"Restrição aceita?"}
    Q -- Não --> R
    Q -- Sim --> H["Gravar histórico, auditoria e tarefas elegíveis"]
    H --> COMMIT["Commit"]
    COMMIT --> END["Responder e processar tarefas posteriormente"]
```

Falha em qualquer gravação antes do commit desfaz toda a operação. O Google pode mudar após a verificação; sincronização posterior deve detectar conflito. Não existe transação distribuída com o Google.

## 6. Confirmar e cancelar

```mermaid
flowchart TD
    A["Paciente envia ação"] --> V["Validar token, finalidade, versão e prazo"]
    V --> OK{"Ação válida?"}
    OK -- Não --> N["Negar sem dados pessoais"]
    OK -- Sim --> K{"Confirmação ou cancelamento?"}
    K -- Confirmação --> F["Transação: confirmar versão atual e manter reserva"]
    K -- Cancelamento --> D{"Data local anterior à véspera?"}
    D -- Sim --> C["Transação: cancelar e liberar reserva"]
    D -- "Véspera ou dia" --> P["Registrar solicitação pendente e manter reserva"]
    D -- "Após data da consulta" --> U["Aplicar somente política aprovada; caso pendente, negar"]
    P --> E["Recepção ou administrador autorizado decide"]
    E --> J{"Aprovar?"}
    J -- Sim --> C
    J -- Não --> R["Registrar decisão; manter consulta"]
    F --> H["Histórico e auditoria na mesma transação"]
    C --> I["Invalidar ações e lembretes; tarefa de remoção Google"]
    I --> H
    H --> M["Commit"]
```

Revalidar versão/estado na decisão da equipe. Se houver reagendamento após solicitação, não cancelar a nova versão silenciosamente. Outras transições dependem da matriz e das regras aprovadas.

## 7. Substituir ou reagendar

```mermaid
flowchart TD
    A["Equipe solicita mudança"] --> B["Autorizar clínica, agenda e consulta"]
    B --> C["Verificar novo horário e Google"]
    C --> T["Iniciar transação e aplicar locks ordenados"]
    T --> V["Revalidar versão e disponibilidade"]
    V --> K{"Tipo de operação"}
    K -- Substituição --> S["Cancelar anterior, liberar reserva e criar nova consulta"]
    K -- Reagendamento --> R["Alterar horário e versão; invalidar confirmação"]
    S --> O["Atualizar reserva global do destino"]
    R --> O
    O --> Q{"Todas as restrições atendidas?"}
    Q -- Não --> FAIL["Rollback: preservar consulta e reserva originais"]
    Q -- Sim --> H["Histórico, auditoria e invalidação de ações antigas"]
    H --> J["Criar tarefas de integração e lembrete elegível"]
    J --> END["Commit; nova consulta exige confirmação"]
```

Substituição requer opção explícita e recepção/administrador no escopo autorizado. Nunca cancelar consulta de outra clínica para liberar o médico. Comunicação da consulta substituída e referência temporal do lembrete reagendado continuam pendentes.

## 8. Lembrete e execução

```mermaid
flowchart TD
    A["Consulta validada na transação"] --> B["Calcular 08h da véspera no fuso da clínica"]
    B --> C{"Antecedência mínima de 24h e horário não perdido?"}
    C -- Não --> N["Não criar lembrete tardio"]
    C -- Sim --> D["Persistir lembrete e tarefa na transação"]
    D --> COMMIT["Commit da consulta e tarefas"]
    COMMIT --> E["Processador obtém tarefa com lease no prazo"]
    E --> F["Revalidar clínica, versão, estado, contato e autorização"]
    F --> G{"Envio permitido?"}
    G -- Não --> X["Invalidar ou encerrar tarefa; registrar motivo"]
    G -- Sim --> H["Enviar pelo adaptador fora da transação"]
    H --> I{"Resultado"}
    I -- Conhecido --> J["Registrar tentativa e situação"]
    I -- Ambíguo --> K["Conciliar antes de reenviar"]
    I -- Falha --> L["Registrar falha; retry depende de política aprovada"]
```

A regra funcional não autoriza lembrete tardio. Limite operacional de processamento e retries precisa ser aprovado. Troca de versão cancela o processamento antigo. Não prometer entrega exatamente uma vez pelo fornecedor.

## 9. Recuperação Google e restauração

```mermaid
flowchart TD
    A["Google volta a responder"] --> B["Revalidar conexão, clínica e versão"]
    B --> C["Consultar ocupação sem tratar próprio evento como conflito"]
    C --> D{"Conflito externo?"}
    D -- Sim --> E["Preservar consulta e reserva; registrar conflito"]
    E --> F["Equipe escolhe novo horário e solicita nova confirmação"]
    D -- Não --> G["Sincronizar e registrar versão publicada"]
```

```mermaid
flowchart TD
    A["Selecionar cópia íntegra"] --> B["Restaurar em ambiente isolado"]
    B --> C["Recuperar configurações e acesso seguro às chaves"]
    C --> D["Verificar Auth, vínculos, RLS, relações, reservas e auditoria"]
    D --> E{"Validação passou?"}
    E -- Não --> F["Manter ambiente isolado; corrigir e repetir validação"]
    E -- Sim --> G["Conciliar tarefas, mensagens e eventos externos"]
    G --> H["Medir perda de dados e tempo de recuperação"]
    H --> I["Liberação operacional controlada; reativar automações"]
```

Um dump padrão não é presumido completo. Backups e configurações têm cobertura documentada em [Supabase](supabase.md). Retenção, frequência e metas continuam pendentes.
