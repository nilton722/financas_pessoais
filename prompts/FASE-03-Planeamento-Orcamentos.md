# Fase 03 — Orçamentos, compromissos, recorrências, metas e dívidas

Ler a especificação. Qualquer alteração de esquema exige migração incremental, nunca recriação da base.

## Objetivo
Implementar planeamento sem misturar compromissos com saldos realizados.

## Tarefas
1. Orçamentos mensais por categoria: limite, gasto realizado, restante e percentagem; excluir transferências.
2. Compromissos futuros de rendimento/despesa com vencimento, conta/categoria opcional, valor e estado.
3. Marcar compromisso como pago criando/associando movimento real; impedir dupla contagem.
4. Se incluir pagamentos parciais, criar alocações explícitas com validação para não exceder o compromisso.
5. Regras recorrentes semanais, mensais e anuais; ocorrências idempotentes com `UNIQUE(rule_id, occurrence_date)`.
6. Ocorrência planeada não altera saldo real até ser paga.
7. Metas de poupança com alvo/data/progresso, sem as tratar como despesas.
8. Dívidas a pagar/receber com saldo pendente baseado em pagamentos reais; adicionar tabela de liquidações quando implementada.
9. Alertas locais opcionais para orçamento e vencimento.
10. Atualizar migrações e backup para as novas tabelas.

## Testes
Compromisso não altera saldo real; pagamento não duplica caixa; cancelamento sai da previsão; recorrência repetida não duplica; orçamento exclui transferências; pagamentos parciais não excedem valor; metas/dívidas só afetam caixa por movimentos reais.

## Aceitação
Planeamento funciona offline e migrações preservam dados existentes.
