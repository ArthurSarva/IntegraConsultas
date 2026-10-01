# ADR-006 — Validação e entrega por etapas

Status: proposto.

## Recomendação

Mudanças separadas por parte do sistema, branches com ID sequencial, commits descritivos e PRs com problema, resultado, validação e limitações. Confirmar conteúdo e branch antes de subir cada nova parte, conforme procedimento do usuário. Merge depende de autorização específica.

Verificações automáticas futuras: tipos, análise estática, build, testes de domínio e integração quando pertinentes. Testes reais de banco devem usar identidade com permissões de aplicação, e não somente superusuário.

## Sequência recomendada

1. Aprovar arquitetura e fechar decisões essenciais de autenticação.
2. Base executável local, configuração e processo de verificação.
3. Migrações de identidade/clínicas e autorização, com testes de isolamento.
4. Pacientes, profissionais e agenda, incluindo ocupação global e concorrência.
5. Tarefas e integrações simuladas.
6. WhatsApp e Google reais em ambiente de testes.
7. Auditoria, relatórios e recuperação.
8. Evidências de lançamento e piloto controlado.

## Evidências necessárias

- Testes de acesso permitido/negado derivados da matriz.
- Operações simultâneas em clínicas distintas para o mesmo médico.
- Confirmação não libera horário; substituição cancela anterior atomicamente.
- Reagendamento invalida tokens e lembretes anteriores.
- Falhas e reinícios não causam tarefas perdidas ou reenvios cegos.
- Restauração verificada e reconciliação antes de reativar integrações.
- Verificação dos fluxos essenciais em navegadores e dispositivos alvo.

## Limites

WCAG 2.2 AA, resposta de até dois segundos em 95% dos casos e prazo de processamento de lembretes são metas propostas, não resultados obtidos. Definir carga e métodos de medição.

Nenhum teste de aplicação ou infraestrutura foi executado neste PR documental. Revisão de LGPD envolve também contratos e operação das clínicas; passar testes técnicos não certifica conformidade jurídica.
