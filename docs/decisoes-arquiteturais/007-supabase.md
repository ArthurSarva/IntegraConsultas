# ADR-007 — Supabase para banco e autenticação

Data: 02/10/2026.
Status: fornecedor aceito pelo responsável pelo projeto. Plano de operação documentado para implementação e validação.

## Contexto e decisão

O IntegraConsultas precisa de banco online gratuito inicialmente, autenticação e suporte a múltiplas clínicas. Foi escolhido Supabase com PostgreSQL padrão e Supabase Auth. Evitar opções de banco em beta no início.

Usar uma base por ambiente, compartilhada entre clínicas com isolamento por permissões. Prever dois projetos: desenvolvimento/testes e produção. A criação dos projetos e o esquema físico serão executados em etapas próprias.

## Alternativas consideradas

Neon para PostgreSQL separado de autenticação; Aiven para PostgreSQL gerenciado; banco por clínica, com maior complexidade para impedir sobreposição do mesmo médico entre clínicas. Supabase reúne banco e identidade, reduzindo configuração inicial.

## Consequências

A autorização clínica continua responsabilidade do IntegraConsultas, conforme [matriz de permissões](../permissoes.md). RLS e autenticação não substituem validação de vínculos, integridade transacional ou auditoria.

O plano gratuito tem limites, pausa por inatividade e não inclui backups automáticos ou PITR. Implantar backups externos e testar restauração. Gratuidade inicial não aprova despesas futuras nem comprova aptidão para lançamento.

PostgreSQL, migrações versionadas, exportação e adaptadores favorecem portabilidade; migrar Supabase Auth exige estratégia específica para identidades e sessões.

## Escopo e validação

Detalhes em [Supabase: adoção e operação](../supabase.md). Framework, ORM, hospedagem da aplicação/processador e metas numéricas permanecem propostas.

Antes de usar dados reais: demonstrar isolamento, segurança, integridade, auditoria e restauração; validar contratos, região e requisitos de privacidade já previstos. Este registro não cria projetos, usuários ou tabelas.

## Fontes

- [Planos](https://supabase.com/pricing)
- [Projetos e cobrança](https://supabase.com/docs/guides/platform/billing-on-supabase)
- [Backups](https://supabase.com/docs/guides/platform/backups)
