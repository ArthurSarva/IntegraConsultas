# ADR-004 — Tarefas persistidas e integrações

Status: proposto.

## Contexto

Envios e Google precisam continuar com navegador fechado, tolerar falhas, respeitar versões e não criar duplicidade. O volume inicial ainda não foi estimado.

## Recomendação

Persistir consulta, ocupação e tarefas na mesma transação (outbox transacional). Processo dedicado lê tarefas devidas, adquire posse temporária e executa adaptadores de WhatsApp e Google.

Usar chave de deduplicação, versão da consulta, expiração, resultado e recuperação de tarefas interrompidas. Não depender de temporizadores na memória ou na requisição web. Limitar concorrência e registrar falhas para operação.

Agenda não chama fornecedores antes de confirmar transação. Lembrete: um agendamento de envio às 8h da véspera; elegibilidade conforme requisitos. Política de repetição após falhas ainda precisa ser aprovada.

Google indisponível não bloqueia gravação interna válida: alerta e pendência. Ao recuperar, consultar ocupação e exigir novo horário se houver conflito, preservando a consulta. Remoção de evento cancelado não deve ser impedida por intervalo ocupado.

## Alternativas

- Fila gerenciada: boa alternativa quando volume justificar; envolve serviço adicional.
- Redis e fila: adicionam infraestrutura antes de comprovar necessidade.
- Cron isolado: pode iniciar verificação de tarefas, mas não substitui persistência, concorrência e histórico.

## Consequências

Menos serviços iniciais, mas banco suporta também carga de tarefas. Falha após fornecedor aceitar e antes de persistir resultado exige conciliação; não prometer exatamente uma vez. Não repetir cegamente operação de envio ambígua.

Definir relógio, fuso, latência, limites e monitoramento. Política de confirmação antes do lembrete e elegibilidade após reagendamento continuam pendentes.

## Validação

Simular reinício do processador, tarefas duplicadas, callback repetido, alteração da consulta antes do envio, credencial revogada e falha externa. Nunca enviar mensagem de uma clínica usando contato ou configuração de outra.

## Adaptadores

- WhatsApp oficial, fornecedor pendente; conteúdo mínimo e modelos aprovados.
- Google Agenda oficial, autorização por médico; evento sem identificação do paciente por padrão.
- Ambiente de teste com adaptadores simulados e sem envio real.

[Requisitos de integração](../requisitos-funcionais.md) continuam sendo a referência funcional.
