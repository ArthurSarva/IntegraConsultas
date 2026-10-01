# Privacidade e segurança

Status: requisitos e plano de adequação; não constitui declaração de conformidade jurídica. Revisão normativa e jurídica é necessária antes da produção e ao alterar finalidades ou fornecedores.

## Governança

- Mapear dados, finalidades, bases legais e compartilhamentos por operação.
- Considerar que informações de agendamento podem revelar dados de saúde.
- Não tratar consentimento como fundamento genérico. Avaliar bases legais aplicáveis a dados sensíveis.
- Separar autorização do WhatsApp das bases legais de cadastro e atendimento.
- Hipótese inicial: clínica controladora de dados de atendimento e IntegraConsultas operador; confirmar responsabilidades por atividade e contrato.
- Definir responsáveis, canal de privacidade, contratos e suboperadores.
- Avaliar necessidade de relatório de impacto, considerando riscos e requisitos aplicáveis.

## Minimização e direitos

- Coletar somente informações necessárias; prontuário e diagnóstico não pertencem ao escopo inicial.
- Disponibilizar aviso de privacidade com finalidades, compartilhamentos e retenção.
- Atender solicitações de direitos com verificação de identidade.
- Exclusão depende de obrigações de conservação e base legal; não prometer apagar qualquer dado imediatamente.
- Definir retenção e descarte para dados, auditoria, mensagens e backups.
- Aplicar proteção e representação adequadas no atendimento de menores.

## Controles técnicos

- Isolamento por clínica, menor privilégio e validação no servidor.
- Contas individuais e autenticação reforçada para Dev e administradores.
- Criptografia em trânsito e armazenamento; tokens protegidos e revogáveis.
- Logs sem conteúdo sensível desnecessário; trilha de auditoria protegida.
- Não inserir dados reais em testes nem segredos no repositório.
- Links de confirmação com validade limitada, escopo restrito e sem dados pessoais na URL.
- Mensagens e eventos Google com conteúdo mínimo.
- Backups protegidos e acesso administrativo auditado.

## Fornecedores e incidentes

Avaliar hospedagem, WhatsApp e Google quanto a contratos, localização, suboperadores e transferências internacionais. Hospedar no Brasil não elimina transferências por outros serviços.

Definir detecção, contenção, avaliação, registro e apoio às comunicações de incidentes. Prazos, enquadramento e responsabilidades devem seguir regulamentação vigente; notificações não serão enviadas automaticamente sem avaliação.

## Referências oficiais

- [LGPD](https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/l13709compilado.htm)
- [Transferências internacionais — Resolução ANPD 19/2024](https://www.gov.br/anpd/pt-br/acesso-a-informacao/institucional/atos-normativos/regulamentacoes_anpd/resolucao-cd-anpd-no-19-de-23-de-agosto-de-2024)
- [Comunicação de incidentes — ANPD](https://www.gov.br/anpd/pt-br/canais_atendimento/agente-de-tratamento/comunicado-de-incidente-de-seguranca-cis)
- [Agentes de pequeno porte — Resolução ANPD 2/2022](https://www.gov.br/anpd/pt-br/acesso-a-informacao/institucional/atos-normativos/regulamentacoes_anpd/resolucao-cd-anpd-no-2-de-27-de-janeiro-de-2022)

Manter revisão periódica de normas e orientações aplicáveis.
