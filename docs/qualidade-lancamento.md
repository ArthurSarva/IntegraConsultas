# Qualidade e critérios de lançamento

## Condições obrigatórias aprovadas

O lançamento depende da aprovação dos cinco critérios abaixo. Todos estão pendentes de implementação e comprovação.

| Critério | Evidências exigidas |
|---|---|
| Isolamento | Testes de acesso cruzado em consultas, alterações, buscas, exportações, relatórios e automações; Dev limitado à clínica selecionada no contexto operacional |
| Segurança | Permissões no servidor, credenciais protegidas, criptografia, autenticação reforçada para Dev e administradores; nenhuma vulnerabilidade crítica ou alta conhecida sem tratamento |
| Integridade da agenda | Testes simultâneos, prevenção de sobreposição e duplicidade, cancelamento e reagendamento com atualização de tarefas |
| Auditoria | Usuário, clínica, ação, data e resultado registrados; proteção contra alteração e acesso restrito |
| Restauração | Recuperação real em ambiente separado, verificação de integridade e comprovação dos prazos acordados |

Cada evidência deve identificar versão testada, ambiente, procedimento, resultado, data e responsável. Falhas devem ser corrigidas e verificadas antes de liberar produção.

## Metas sugeridas, ainda não aprovadas

| Área | Proposta |
|---|---|
| Desempenho | Até 2 segundos em 95% das principais ações, sob carga acordada |
| Disponibilidade | 99,5% mensal; método de medição e manutenção a definir |
| Lembretes | Iniciar processamento até 5 minutos do horário previsto em condições normais; entrega depende do fornecedor |
| Recuperação | RPO de 1 hora e RTO de 4 horas, sujeitos à infraestrutura |
| Compatibilidade | Duas versões principais mais recentes de Chrome, Edge, Firefox e Safari; Android e iOS |
| Acessibilidade | WCAG 2.2 AA |
| Capacidade | Definir clínicas, usuários simultâneos, consultas e mensagens por dia |

RPO é perda máxima de dados tolerada; RTO é tempo máximo para recuperar o serviço.

## Práticas propostas

Ambientes separados, dados fictícios em testes, verificações automáticas, migrações versionadas, reversão documentada, monitoramento de falhas e atrasos e alertas aos responsáveis.

A aprovação técnica não substitui a validação jurídica e operacional de privacidade.
