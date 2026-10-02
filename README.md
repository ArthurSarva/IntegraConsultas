# IntegraConsultas

Aplicação web para agendamento de consultas de múltiplas clínicas, lembretes pelo WhatsApp e integração com o Google Agenda dos médicos.

## Estado do projeto

Fase de base inicial e documentação. Esta documentação registra os acordos até 02/10/2026; não representa aplicação clínica pronta nem certificação de conformidade com a LGPD.

Banco e autenticação: Supabase (PostgreSQL e Supabase Auth), escolha aprovada em 02/10/2026. Base local de identidade, clínicas, vínculos e isolamento disponível; projeto online e aplicação web ainda não configurados.

## Desenvolvimento

Consulte [base Supabase e testes](docs/base-supabase.md) para preparar o ambiente local e conhecer o escopo implementado.

## Documentação

- [Requisitos funcionais e permissões](docs/requisitos-funcionais.md)
- [Modelo de dados proposto](docs/modelo-dados.md)
- [Arquitetura do banco](docs/arquitetura-banco.md)
- [Diagramas e fluxogramas do banco](docs/fluxograma-banco.md)
- [Arquitetura proposta](docs/arquitetura.md)
- [Decisões arquiteturais](docs/decisoes-arquiteturais/README.md)
- [Supabase: ambientes, segurança e recuperação](docs/supabase.md)
- [Privacidade e segurança](docs/privacidade-seguranca.md)
- [Qualidade e critérios de lançamento](docs/qualidade-lancamento.md)
- [Decisões pendentes e execução](docs/decisoes-pendentes.md)

## Diretrizes

A agenda oficial pertence ao IntegraConsultas. Cada clínica possui dados e permissões isolados. O início operacional será com uma clínica, mantendo suporte a múltiplas clínicas. Segurança, isolamento, integridade da agenda, auditoria e restauração de backups são condições obrigatórias de lançamento.

Não inserir dados reais de pacientes, senhas, tokens ou credenciais neste repositório.

