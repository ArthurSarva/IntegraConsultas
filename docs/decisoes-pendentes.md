# Decisões pendentes e execução

## Acordos

Aplicação web; agenda própria; suporte a clínicas isoladas; funções por vínculo; Dev com seletor de clínica; WhatsApp; publicação de consultas no Google e consulta de ocupação externa; critérios obrigatórios de lançamento.

## Decisões necessárias

| Tema | Definir |
|---|---|
| Infraestrutura | Aprovar stack, hospedagem, orçamento e capacidade esperada |
| WhatsApp | Número, fornecedor, configuração oficial, modelos, custos e política de autorização |
| Google | Calendários por clínica, permissões, configuração OAuth, conflitos e comportamento sem conexão |
| Agenda | Transições de estados, cancelamento solicitado pelo paciente e regras de alteração |
| Duração | Se alterações no padrão afetam somente novas consultas e como tratar exceções |
| Autoagendamento | Identificação, horários disponíveis, antecedência, limites e regras de cancelamento |
| Encaixes | Perfis autorizados e regra de conflito, mantendo integridade |
| Lista de espera | Elegibilidade, prioridade, contato e eventual reserva temporária |
| Recorrência | Incluir ou não consultas recorrentes |
| Lembretes | Quantidade, antecedência, horários permitidos e consultas com pouca antecedência |
| Acesso | Matriz detalhada por função, escopo próprio e acúmulo de funções |
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
