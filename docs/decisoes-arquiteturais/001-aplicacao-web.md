# ADR-001 — Aplicação web modular

Status: proposto.

## Contexto

Aplicação web responsiva, agenda oficial própria, múltiplas clínicas e automações independentes do navegador. Portabilidade e manutenção simples são prioridades.

## Recomendação

Next.js e TypeScript em runtime Node.js suportado, com aplicação organizada em módulos e processo de automação separado no mesmo repositório. Compartilhar regras de domínio entre servidor e processador; não acoplar regras à interface.

Módulos: identidade e acesso, clínicas, pacientes, profissionais, agenda, lista de espera, comunicação, calendário, auditoria e relatórios. Estrutura de pastas e bibliotecas ainda serão definidas.

Interfaces web chamam operações de servidor que validam identidade, clínica, escopo e dados. Todas as entradas, incluindo retornos de fornecedores, são validadas em execução; TypeScript não substitui validação.

Empacotar aplicação e processador em contêineres. Segredos e configuração externos ao código. Não depender de APIs exclusivas de um provedor para regras de negócio.

## Alternativas

- Interface React e API separada: maior independência, mas mais componentes de implantação.
- Backend em outra linguagem: válido se experiência da equipe justificar; pode aumentar duplicação e integração.
- Microserviços: desnecessários sem carga ou organização que justifique a complexidade.

## Consequências

Menor quantidade de componentes iniciais e regras centralizadas. Aplicação e processador podem escalar separadamente. Módulos exigem limites claros para evitar dependências circulares.

Dados autenticados não devem usar cache público. Contexto de clínica e usuário precisa integrar qualquer cache autorizado; mudanças de permissão exigem invalidação. Exportação estática isolada não atende ao servidor de agenda e integrações.

## Validação

Build e execução em contêiner; fluxos essenciais em navegadores alvo; nenhum token ou dado privado incluído no pacote cliente; autorização em cada operação; teste de cache entre clínicas.

## Fonte

[Self-hosting do Next.js](https://nextjs.org/docs/app/guides/self-hosting). A documentação contempla execução própria em servidor Node.js e contêineres; configuração de proxy e cache deve acompanhar a implantação escolhida.
