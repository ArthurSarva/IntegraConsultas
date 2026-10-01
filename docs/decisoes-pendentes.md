# Decisões pendentes e execução

## Acordos

Aplicação web; agenda própria; suporte a clínicas isoladas; funções por vínculo; Dev com seletor de clínica; WhatsApp; publicação de consultas no Google e consulta de ocupação externa; critérios obrigatórios de lançamento.

## Regras confirmadas nesta atualização

- Encaixes somente em horários livres; caixa de seleção para substituir consulta existente, preservando histórico e atualizando integrações.
- Cancelamento imediato pelo paciente antes da véspera, pela data local da clínica; na véspera ou no dia, aprovação necessária.
- Médico com função de recepção gerencia somente a própria agenda.
- Falha do Google permite agendamento com alerta e atualização pendente para recuperação posterior.
- Autoagendamento adiado para versão futura.
- Profissional que agenda pode escolher duração excepcional; limites pendentes.

## Decisões necessárias

| Tema | Definir |
|---|---|
| Infraestrutura | Aprovar stack, hospedagem, orçamento e capacidade esperada |
| WhatsApp | Número, fornecedor, configuração oficial, modelos, custos e política de autorização |
| Google | Calendários por clínica, permissões, configuração OAuth, tratamento de conflitos após recuperação |
| Agenda | Transições de estados, aprovadores de cancelamento e regras de alteração; cancelamento automático antes da véspera já definido |
| Duração | Efeito de alterações no padrão e valores/limites de exceções escolhidas pelo profissional; padrão de 15, 30, 45 ou 60 minutos |
| Autoagendamento | Versão futura: identificação, horários disponíveis, antecedência, limites e regras; fora da implementação inicial |
| Encaixes | Perfis autorizados e tratamento da substituição via caixa de seleção; encaixe somente em horário livre |
| Lista de espera | Elegibilidade, prioridade, contato e eventual reserva temporária |
| Recorrência | Incluir ou não consultas recorrentes |
| Lembretes | Quantidade, antecedência, horários permitidos e consultas com pouca antecedência |
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
