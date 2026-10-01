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
- Lista de espera segue ordem de contato, cujo significado operacional está pendente.
- Um lembrete às 8h da véspera; não enviar para agendamentos com menos de 24 horas nem após perda desse horário.
- Conflito revelado pelo Google exige novo horário, preservando a consulta e sinalizando conflito.
- Recepção e administrador editam pacientes, consultam informações e bloqueiam horários; somente administrador exporta.
- Infraestrutura gratuita, normas e metas de qualidade sugeridas ainda não foram aprovadas.

## Decisões necessárias

| Tema | Definir |
|---|---|
| Infraestrutura | Aprovar stack, hospedagem, orçamento e capacidade esperada |
| WhatsApp | Número, fornecedor, configuração oficial, modelos, custos e política de autorização |
| Google | Calendários por clínica, permissões, configuração OAuth, tratamento técnico da recuperação; decisão funcional de exigir novo horário já aprovada |
| Agenda | Transições detalhadas e solicitações após a consulta; recepção e administrador são os aprovadores |
| Duração | Efeito de alterações no padrão; qualquer duração fica restrita a 15, 30, 45 ou 60 minutos |
| Autoagendamento | Versão futura: identificação, horários disponíveis, antecedência, limites e regras; fora da implementação inicial |
| Encaixes | Destino e comunicação da consulta substituída; recepção e administrador autorizados |
| Lista de espera | Esclarecer ordem de contato, elegibilidade, forma de contato e reserva temporária |
| Recorrência | Incluir ou não consultas recorrentes |
| Lembretes | Repetição após falhas, prazo de processamento e efeitos da confirmação; regra das 8h da véspera já definida |
| Acesso | Matriz detalhada por função; médico com recepção limitado à própria agenda |
| Privacidade | Bases legais, contratos, retenção, responsáveis e fornecedores |
| Qualidade | Aprovar metas de desempenho, capacidade, disponibilidade e recuperação |
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
