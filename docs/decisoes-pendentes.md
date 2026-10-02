# Decisões pendentes e execução

## Acordos

Aplicação web; agenda própria; suporte a clínicas isoladas; funções por vínculo; Dev com seletor de clínica; WhatsApp; publicação de consultas no Google e consulta de ocupação externa; critérios obrigatórios de lançamento.

## Regras confirmadas nesta atualização

- Encaixes somente em horários livres; caixa de seleção para substituir consulta existente, preservando histórico e atualizando integrações.
- Cancelamento imediato pelo paciente antes da véspera, pela data local da clínica; na véspera ou no dia, aprovação necessária.
- Médico com função de recepção gerencia somente a própria agenda.
- Falha do Google permite agendamento com alerta e atualização pendente para recuperação posterior.
- Autoagendamento adiado para versão futura.
- Duração específica restrita a 15, 30, 45 ou 60 minutos.
- Recepção e administrador aprovam cancelamentos, substituem consultas e registram conclusão ou falta.
- Reagendamento exige nova confirmação.
- Lista de espera segue ordem cronológica do primeiro pedido.
- Agendada e confirmada ocupam horário; concluída, cancelada e falta não ocupam.
- Impedir sobreposição do mesmo médico entre clínicas sem revelar dados de outra clínica.
- Substituição cancela a consulta anterior e preserva histórico.
- Um lembrete às 8h da véspera; não enviar para agendamentos com menos de 24 horas nem após perda desse horário.
- Conflito revelado pelo Google exige novo horário, preservando a consulta e sinalizando conflito.
- Recepção e administrador editam pacientes, consultam informações e bloqueiam horários; somente administrador exporta.
- Supabase aprovado para PostgreSQL e autenticação em 02/10/2026; início no plano gratuito e separação de desenvolvimento/testes e produção documentados em [Supabase](supabase.md).
- Hospedagem da aplicação e das automações, normas detalhadas e metas numéricas de qualidade continuam pendentes.

## Decisões necessárias

| Tema | Definir |
|---|---|
| Infraestrutura | Supabase escolhido; definir região, conta responsável, capacidade, hospedagem da aplicação e das automações, orçamento e critérios de evolução do plano |
| WhatsApp | Número, fornecedor, configuração oficial, modelos, custos e política de autorização |
| Google | Calendários por clínica, permissões, configuração OAuth, tratamento técnico da recuperação; decisão funcional de exigir novo horário já aprovada |
| Agenda | Transições detalhadas e solicitações após a consulta; recepção e administrador são os aprovadores |
| Duração | Efeito de alterações no padrão; qualquer duração fica restrita a 15, 30, 45 ou 60 minutos |
| Autoagendamento | Versão futura: identificação, horários disponíveis, antecedência, limites e regras; fora da implementação inicial |
| Encaixes | Comunicação da consulta substituída; destino cancelada e perfis já definidos |
| Lista de espera | Elegibilidade, desempate, forma de contato e reserva temporária; prioridade pelo primeiro pedido |
| Recorrência | Incluir ou não consultas recorrentes |
| Lembretes | Repetição após falhas, prazo de processamento e efeitos da confirmação; regra das 8h da véspera já definida |
| Acesso | Supabase Auth escolhido; validar convite, recuperação, sessões, MFA e revogação conforme matriz de permissões; médico com recepção limitado à própria agenda |
| Privacidade | Bases legais, contratos, retenção, responsáveis e fornecedores |
| Qualidade | Aprovar metas de desempenho, capacidade, disponibilidade e recuperação; definir destino, frequência, retenção e responsável por backups externos e comprovar restauração |
| Online | Origem dos links; geração automática de videoconferência não definida |

## Sequência proposta

1. Revisar esta documentação e resolver decisões que bloqueiam o modelo de dados.
2. Detalhar permissões, entidades e fluxos.
3. Implementar autenticação, contexto de clínica e isolamento.
4. Implementar pacientes, profissionais e agenda.
5. Implementar automação com envio simulado.
6. Integrar WhatsApp e Google.
7. Implementar relatórios, auditoria e operação de backups.
8. Comprovar critérios de lançamento, revisar privacidade e executar piloto controlado.

Esta sequência é proposta; não fixa prazo nem contratação. Até a criação desta documentação não havia código de aplicação no repositório.
