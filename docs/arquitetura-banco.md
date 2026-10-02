# Arquitetura do banco de dados

Data: 02/10/2026. Status: proposta física para revisão, baseada no [modelo lógico](modelo-dados.md), [permissões](permissoes.md) e [adoção do Supabase](supabase.md). Nenhum SQL, projeto ou infraestrutura é criado por esta documentação.

## 1. Organização

Um projeto Supabase por ambiente: desenvolvimento/testes com dados fictícios e produção separado. Um PostgreSQL padrão compartilhado entre clínicas por ambiente permite transações de agenda e ocupação global do médico. Supabase Auth cuida da identidade; funções e escopos são definidos pelo IntegraConsultas.

Schemas propostos abaixo representam limites de acesso, não serviços independentes. Nomes finais dependem da prova técnica.

| Schema | Conteúdo | Acesso proposto |
|---|---|---|
| auth | Usuários e sessões geridos pelo Supabase | APIs de Auth; sem edição direta comum |
| app | Clínicas, usuários locais, vínculos, funções, profissionais, pacientes, agenda e comunicação | Servidor com identidade autenticada, RLS e grants mínimos |
| private | Identidade médica global, ocupação e tokens de ação | Sem exposição na Data API; rotinas autorizadas |
| integration | Tarefas, tentativas, conexões e mapeamento Google/WhatsApp | Servidor e processador com escopo explícito |
| audit | Eventos de acesso e ação | Escrita controlada; leitura por clínica e perfil |
| api | Fachada opcional de funções/views autorizadas | Expor somente operações aprovadas |

Não expor schemas de negócio automaticamente. Exposição na Data API, GRANT e RLS são controles distintos; nenhum deles sozinho autoriza acesso. Funções de escrita de agenda precisam encapsular toda a transação, pois várias chamadas REST não formam uma única transação.

## 2. Limites e relações

Referência completa dos campos e cardinalidades: [modelo lógico](modelo-dados.md). Diagramas resumidos: [fluxogramas do banco](fluxograma-banco.md).

| Domínio | Tabelas lógicas | Relações e controle |
|---|---|---|
| Identidade | USER, CLINIC, MEMBERSHIP, ROLE_ASSIGNMENT | USER referencia identidade Auth estável; vínculo único por usuário/clínica; funções pertencem ao vínculo |
| Profissionais | PROFESSIONAL, AVAILABILITY, BLOCK | Profissional local aponta vínculo e identidade médica global verificada |
| Pacientes | PATIENT, RESPONSIBLE, PATIENT_RESPONSIBLE, CONTACT, MESSAGE_AUTHORIZATION | Cadastros por clínica; telefone compartilhado permitido; autorização de canal separada da base legal |
| Agenda | APPOINTMENT, APPOINTMENT_HISTORY, CONFIRMATION, CANCELLATION_REQUEST | Consulta liga paciente e profissional da mesma clínica; versão protege ações e confirmações |
| Ocupação privada | PHYSICIAN_IDENTITY, PHYSICIAN_OCCUPANCY | Uma identidade pode ter profissionais em várias clínicas; reserva mínima global por consulta |
| Ações privadas | ACTION_TOKEN | Hash, finalidade, consulta, versão, expiração e consumo; nenhum token em claro |
| Espera | WAITLIST_ENTRY, WAITLIST_CONTACT | Prioridade pela data do primeiro pedido; elegibilidade e desempate pendentes |
| Comunicação | REMINDER, MESSAGE_ATTEMPT, WHATSAPP_CONNECTION | Destinatário e autorização verificados antes de enviar |
| Google | GOOGLE_CONNECTION, CALENDAR_BINDING, CALENDAR_EVENT, EXTERNAL_CONFLICT | Vínculo por profissional/clínica; versões desejada e sincronizada; conflito separado do estado |
| Execução | TASK | Tarefa persistida com a consulta; chave de deduplicação, prazo, versão e lease |
| Auditoria | AUDIT_EVENT | Ator, clínica, ação, recurso, resultado, correlação e instante |

PHYSICIAN_OCCUPANCY detalha a projeção mínima já proposta no modelo lógico; não substitui APPOINTMENT. Campos propostos: id, clinic_id, appointment_id, physician_identity_id, starts_at, ends_at. Não contém paciente nem conteúdo clínico. Somente consultas agendadas/confirmadas mantêm reserva ativa; liberar reserva não exclui consulta ou histórico.

## 3. Chaves, tipos e integridade

- UUID para identificadores; USER aponta o subject estável do Supabase Auth, sem usar email como identidade.
- clinic_id obrigatório em entidades operacionais. Auditoria global pode ter clínica nula somente em ação global explicitamente identificada.
- Cada pai local permite referência por (clinic_id, id); chaves estrangeiras compostas impedem consulta com paciente, contato ou profissional de outra clínica.
- Relações globais são exceções explícitas: identidade de usuário e médico. Não adicionar dados de pacientes à identidade global.
- Instantes em timestamptz; fuso IANA da clínica para regras de data e envio. Disponibilidade semanal usa hora local e vigência.
- Intervalos semiabertos [início, fim), permitindo consultas consecutivas.
- Duração padrão/específica somente 15, 30, 45 ou 60 minutos; fim coerente com início e duração.
- Cinco estados da consulta; conflito externo e pedido de cancelamento são registros separados.
- Versão inteira para concorrência otimista e invalidação de tokens, confirmações e tarefas antigas.
- Unicidades para vínculo, função, reserva por consulta, lembrete por versão/tipo e deduplicação de tarefas.
- Restrições e índices não substituem autorização; erros técnicos não podem revelar clínica ou consulta externa.
- Sem remoção em cascata indiscriminada. Retenção e atendimento de direitos dependem de política aprovada.

## 4. Concorrência e ocupação

Proposta: restrição de exclusão GiST por identidade médica e intervalo na ocupação global, com extensão btree_gist se necessária e suportada. Tipos, versão e extensões serão verificados na implementação. A restrição é a proteção final para tentativas simultâneas; consultar disponibilidade antes de gravar não basta.

Consultas e reservas mudam na mesma transação. Padronizar locks e sua ordem por identidade médica para serializar também operações de disponibilidade/bloqueio concorrentes. Um bloqueio de agenda e um agendamento precisam usar o mesmo protocolo, com revalidação após obter o lock. O alcance global dos bloqueios manuais entre clínicas permanece pendente; não inferir essa regra da ocupação global de consultas.

Reagendamento reserva o destino e libera a origem atomicamente: se o destino falhar, preservar a consulta e a reserva originais. Substituição cancela anterior e insere nova na mesma transação; somente consulta da clínica e escopo autorizados. Em falha, desfazer tudo.

Confirmar mantém reserva. Cancelar, concluir e marcar falta liberam reserva conforme transição permitida. Solicitação pendente e conflito Google não liberam.

## 5. Autorização

RLS no app e em qualquer tabela de schema exposto; preferir também em schemas privados como defesa adicional. Grants mínimos por operação. USING e WITH CHECK devem impedir acesso e alteração de clínica; UPDATE depende também da política SELECT.

Servidor valida identidade e contexto; políticas verificam vínculos atuais. Não confiar em clinic_id, função do navegador ou user_metadata. Revogação deve valer mesmo com JWT antigo. A forma de contexto para clínica selecionada será testada com pooling; não depender de estado de conexão persistente.

Dev opera em uma clínica selecionada por vez. Exportação só para administrador vinculado. Médico com recepção continua restrito à agenda própria. Ações pendentes na matriz permanecem negadas.

Views com security_invoker quando aplicável ou sem acesso comum. Preferir SECURITY INVOKER; eventual rotina ampliada de ocupação global fica privada, com search_path seguro, nomes qualificados, grants explícitos, validação de ator/escopo e resposta livre/ocupado. Revogar EXECUTE de PUBLIC e não oferecer leitura global às recepções.

Chave secret/service_role e identidade proprietária não serão usadas em rotas clínicas comuns. Processador, migrações e recuperação têm identidades e permissões separadas. Segredos ficam fora das tabelas comuns, referenciados por identificadores protegidos.

Paciente por link não recebe leitura genérica do banco; uma operação restrita valida token, versão, finalidade e prazo antes de agir.

## 6. Índices propostos

| Consulta frequente | Índice/caminho |
|---|---|
| Agenda | clinic_id, professional_id, starts_at |
| Pacientes | clinic_id e campos de busca aprovados |
| Vínculos | unicidade clinic_id, user_id; situação |
| Ocupação global | exclusão por médico/intervalo; unicidade da consulta |
| Tarefas prontas | situação, due_at; avaliar índice parcial |
| Histórico | clinic_id, appointment_id, versão/instante |
| Auditoria | clinic_id, occurred_at |
| Espera | clinic_id, entered_at |
| Eventos externos | contexto da conexão/calendário e event_id |

Validar com volume representativo e planos de execução; não prometer metas ainda não aprovadas. Índices e auditoria consomem a cota de armazenamento.

## 7. Automação e recuperação

Outbox persistida na mesma transação da consulta. Processador obtém lease, revalida versão/estado/autorização, executa adaptador e registra resultado. Não manter transação do banco aberta durante chamada externa.

Falhas ambíguas são conciliadas antes de repetir; política de retries permanece pendente. Google e WhatsApp não participam da transação PostgreSQL. Eventos e mensagens já externos exigem reconciliação após restauração.

Backups externos criptografados devem cobrir schemas de negócio, identidades Auth necessárias, políticas, funções e auditoria; testar cobertura do método. Configurações e segredos exigem recuperação separada; Storage, se utilizado, exige cópia de objetos. Frequência, retenção, destino e RPO/RTO ainda pendentes. [Plano de recuperação](supabase.md).

## 8. Validação antes da infraestrutura clínica

Comprovar isolamento de leitura/escrita, troca de contexto, revogação, MFA, médico com recepção, Dev selecionado, exportação restrita, concorrência global, substituição e reagendamento atômicos, deduplicação e restauração.

Pendências: identidade única verificada do médico; campos mínimos e acesso aos pacientes; transições detalhadas; referência temporal do lembrete reagendado; bloqueios entre clínicas; regras de espera e retry; contexto seguro para pooling; método de migração; configuração de recuperação.

## Referências

- [Segurança da API Supabase](https://supabase.com/docs/guides/api/securing-your-api)
- [RLS Supabase](https://supabase.com/docs/guides/database/postgres/row-level-security)
- [Intervalos PostgreSQL](https://www.postgresql.org/docs/current/rangetypes.html)
- [Backups Supabase](https://supabase.com/docs/guides/platform/backups)
