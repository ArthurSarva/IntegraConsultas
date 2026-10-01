# ADR-005 — Ambientes, hospedagem e recuperação

Status: proposto; fornecedores, orçamento e metas numéricas pendentes.

## Recomendação

Desenvolvimento local em contêineres, PostgreSQL e integrações simuladas. Ambiente de teste separado com dados fictícios. Produção com aplicação, processador e PostgreSQL em serviços que atendam aos critérios de lançamento.

Preferir hospedagem gerenciada de baixo custo para reduzir manutenção. Gratuidade é útil para avaliação, mas não supera requisitos de disponibilidade, tarefas, backup, contratos e segurança.

Separar configuração, credenciais, números WhatsApp, OAuth e bases de cada ambiente. Segredos nunca no GitHub ou em exemplos de documentação.

## Opções

| Opção | Avaliação |
|---|---|
| Local | Gratuito para desenvolver; depende da máquina e não é ambiente clínico de produção |
| Plano gratuito remoto | Demonstração; revisar suspensão, expiração, limites e uso comercial |
| Serviços gerenciados pagos | Recomendação para piloto real, condicionada a contratos e testes |
| Servidor próprio/VPS | Pode reduzir custo direto, mas exige responsável por patches, segurança e recuperação |

O Render gratuito não é recomendado pelo fornecedor para produção e possui limitações de suspensão e banco. Vercel Hobby restringe uso comercial. Não selecionar esses planos para operação clínica por serem gratuitos.

## Recuperação e monitoramento

Backups criptografados em destino separado, retenção a definir, monitoramento de execução e restauração real em ambiente isolado. Incluir configurações e acesso seguro às chaves necessárias à recuperação.

Backups do banco não recuperam mensagens já entregues ou mudanças no Google. Após restauração, reconciliar tarefas e eventos antes de reativar automações para não reenviar lembretes antigos.

Monitorar erros, atrasos, conflitos, integração revogada, tentativas e backups. Não expor conteúdo de pacientes em telemetria.

## Metas propostas, ainda não aprovadas

Disponibilidade de 99,5% mensal; perda máxima de dados de uma hora (RPO); recuperação em quatro horas (RTO); revisão de restauração trimestral. Confirmar orçamento, método de medição e capacidade antes de assumir compromissos.

## Critério obrigatório

Restauração demonstrada, isolamento, segurança, integridade e auditoria são bloqueadores de lançamento já aprovados. Infraestrutura precisa comprovar esses requisitos; nenhum plano está aprovado apenas por esta proposta.

## Fontes

- [Limitações do Render gratuito](https://render.com/docs/free)
- [Vercel Hobby](https://vercel.com/docs/plans/hobby)
