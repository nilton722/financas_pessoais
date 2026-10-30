# Modelo de dados local (SQLite)

Fonte de verdade local, gerida por Drift. Versão atual do esquema: **4**.
Registo audível das migrações na tabela `schema_migrations`; o ponteiro interno
do SQLite (`user_version`) é mantido pelo Drift com o mesmo valor.

## Convenções

- IDs: UUID em `TEXT` (permite sincronização futura sem redesenho).
- Montantes: `INTEGER` em FCFA/XOF, nunca `double`.
- Datas financeiras: `TEXT` `YYYY-MM-DD`.
- Timestamps técnicos: `TEXT` ISO-8601 UTC (`...Z`) em `created_at`/`updated_at`.
- `PRAGMA foreign_keys = ON` em cada abertura da ligação.
- Várias escritas relacionadas usam transação (`transaction()` do Drift).

Estas convenções são impostas na base por `CHECK` constraints de formato e por
`CHECK` de domínio (montante positivo, tipo de movimento, coerência de
transferência).

## v1 — tabelas criadas nesta fase

### `accounts`

`id`, `name`, `type` (`cash`/`bank`/`mobile_wallet`/`savings`/`other`),
`currency_code` (defeito `XOF`), `opening_balance` (inteiro), `opening_date`,
`is_archived`, `created_at`, `updated_at`.

### `categories`

`id`, `name`, `kind` (`income`/`expense`), `icon_key`, `color_value`,
`is_system`, `is_archived`, `created_at`, `updated_at`.
Índice único parcial `uq_categories_active_name(kind, name) WHERE is_archived = 0`:
dois nomes ativos iguais do mesmo tipo são rejeitados; categorias arquivadas
libertam o nome.

### `transactions`

`id`, `kind` (`income`/`expense`/`transfer`), `account_id`, `destination_account_id`,
`category_id`, `amount` (`CHECK > 0`), `transaction_date`, `description`,
`notes`, `created_at`, `updated_at`, `deleted_at`.

Regras garantidas na base:

- `transfer` exige `destination_account_id` e `destination_account_id <> account_id`;
- `income`/`expense` exigem `destination_account_id IS NULL`.
- Índices: `transaction_date`, `account_id`, `category_id`, `kind`.

**Política de eliminação (ADR-016):** `deleted_at` preenchido marca registo
eliminado. Registos eliminados ficam fora de saldos, orçamentos e relatórios e
nunca são apagados fisicamente. Todas as consultas da Fase 02 filtram por
`deleted_at IS NULL`.

### `app_settings`

`key`, `value`, `updated_at`. Chaves semeadas: `currency_code`, `locale`,
`time_zone`.

### `schema_migrations`

`version` (PK), `applied_at`. Cada migração insere a sua linha.

## Saldos (calculados, Fase 02)

Não existe coluna de saldo. O saldo por conta é:

```text
saldo_inicial
  + rendimentos − despesas da conta
  − transferências saídas da conta
  + transferências entradas na conta
```

todas com `deleted_at IS NULL` e `transaction_date <= data_de_referência`.
O cálculo corre numa única consulta agregada (`AccountRepository.watchBalances`
/ `readBalances`): três ramos `UNION ALL` produzem o delta por conta
(rendimento/despesa, débito da transferência, crédito no destino), ficando a
aritmética final no domínio (`AccountBalance.balance`).

Consequências:

- Transferências entre contas próprias anulam-se no consolidado; só as contas
  ativas e da mesma moeda entram na soma (`consolidatedBalance`);
- Corrigir ou eliminar um movimento passado recalcula saldos e relatórios sem
  passos de migração de dados;
- Consultas SQL personalizadas declaram `readsFrom` para que os streams do
  Drift invalidationem ao escrever em `transactions`/`accounts`.

Os repositórios expõem dois modos de leitura, com a mesma consulta: `watch*`
(subscrição para a interface) e `read*` (leitura pontual, usada em testes e
futuros relatórios). O Drift devolve o último resultado em cache ao re-subserver
uma consulta igual, pelo que uma leitura pontual não deve usar `stream.first`
depois de escrever.

## Alterações de esquema na Fase 02

Nenhuma. Contas, categorias, movimentos, índices e `deleted_at` já existiam na
v1; a Fase 02 apenas os usou. A versão do esquema continuou em **1**.

## v2 — compromissos, pagamentos e recorrências

### `planned_items`

`id`, `kind` (`income`/`expense`), `account_id` e `category_id` opcionais,
`amount` (`CHECK > 0`), `due_date`, `description`, `status`
(`planned`/`partially_paid`/`paid`/`cancelled`), `transaction_id` opcional,
`created_at`, `updated_at`.

- `status` e `transaction_id` são indicadores auxiliares. O estado efetivo é
  sempre derivado de `paid_total`, tal como em `PlannedItem.effectiveStatus`:
  cancelado prevalece; pago quando o total alocado cobre o valor; parcial
  quando existe algum pagamento real.
- O compromisso em si **nunca** entra no cálculo de saldo.

### `planned_item_payments`

`id`, `planned_item_id`, `transaction_id`, `amount`, `payment_date`,
`created_at`. `UNIQUE(transaction_id)` garante que um movimento real liquida no
máximo um compromisso; a soma alocada nunca excede `planned_items.amount`
(validado no repositório e nas transações SQLite, porque um `CHECK` não pode
consultar outra tabela).

Eliminar ou editar o movimento associado atualiza a alocação e o estado do
compromisso na mesma transação (`TransactionRepository`) — ver ADR-021.

### `recurring_rules`

`id`, `kind`, `account_id`/`category_id` opcionais, `amount`, `frequency`
(`weekly`/`monthly`/`yearly`), `start_date`, `end_date` opcional,
`next_occurrence_date`, `description`, `is_active`, timestamps.
As datas derivam sempre de `start_date`; meses curtos não perdem o dia
original (31 Jan → 28/29 Fev → 31 Mar) — ver ADR-020.

### `recurring_occurrences`

`id`, `rule_id`, `occurrence_date`, `planned_item_id` opcional,
`transaction_id` opcional, `status` (`planned`/`paid`/`cancelled`),
`created_at`. `UNIQUE(rule_id, occurrence_date)` torna a geração idempotente:
repetir `syncRecurrences` não cria duplicados.

### Índices v2

`idx_planned_items_due_date`, `idx_planned_items_status`,
`idx_planned_item_payments_item`, `idx_recurring_rules_active`,
`idx_recurring_occurrences_rule`.

## v3 — orçamentos mensais

### `budgets`

`id`, `category_id`, `period_type` (apenas `monthly`), `period_start`
(`YYYY-MM-01`), `limit_amount` (`CHECK >= 0`), `created_at`, `updated_at`.
`UNIQUE(category_id, period_type, period_start)` impede dois limites para a
mesma categoria e mês; guardar de novo atualiza o limite.

O gasto **não é guardado**. É calculado em SQL:

```text
gasto(categoria, mês) = SUM(transactions.amount)
  WHERE kind = 'expense'
    AND deleted_at IS NULL
    AND category_id = categoria
    AND transaction_date >= period_start
    AND transaction_date < date(period_start, '+1 month')
```

Transferências ficam de fora por `kind = 'expense'`; rendimentos e registos
eliminados também. Receita e despesa da categoria não se compensam — o
orçamento de despesa acompanha apenas despesas reais (ADR-022).

Índice: `idx_budgets_period(period_type, period_start)`.

## v4 — metas de poupança e dívidas

### `savings_goals`

`id`, `name`, `target_amount` (`CHECK > 0`), `target_date` opcional,
`linked_account_id` opcional, `notes` opcional, `is_archived`, timestamps.

O progresso não é guardado: é o saldo real da conta associada
(`AccountRepository.readBalances`), pelo que só movimentos reais o alteram.
Metas não são despesas e nunca subtraem ao saldo (ADR-023).

### `debts`

`id`, `kind` (`payable`/`receivable`), `counterparty` opcional, `description`,
`original_amount` (`CHECK > 0`), `due_date` opcional, `status`
(`open`/`paid`/`cancelled`), timestamps.

### `debt_payments`

`id`, `debt_id`, `transaction_id`, `amount`, `payment_date`, `created_at`.
`UNIQUE(transaction_id)` impede imputar o mesmo movimento a duas dívidas.

O pendente é `original_amount − SUM(pagamentos cujo movimento não está
eliminado)`; o estado efetivo também deriva desse total. Liquidações criam um
movimento `expense` (a pagar) ou `income` (a receber), exatamente um por
pagamento (ADR-024).

### Índices v4

`idx_savings_goals_archived`, `idx_debts_status`,
`idx_debt_payments_debt`.

## Seeds (idempotentes)

Inseridos com `INSERT OR IGNORE` em cada abertura, usando UUIDs fixos — uma
segunda inicialização não duplica nada e não sobrescreve alterações do
utilizador.

- 11 categorias de sistema: 3 de rendimento (Salário, Trabalho independente,
  Outros rendimentos) e 8 de despesa (Alimentação, Transporte, Habitação,
  Saúde, Educação, Lazer, Comunicações, Outras despesas).
- 3 configurações: `currency_code=XOF`, `locale=pt_PT`, `time_zone=Africa/Bissau`.

Não são criadas contas nem movimentos fictícios.

## Plano de migrações

| Versão | Fase | Tabelas |
|---|---|---|
| 1 | 01 (feita) | `accounts`, `categories`, `transactions`, `app_settings`, `schema_migrations` |
| 2 | 03 (feita) | `planned_items`, `planned_item_payments`, `recurring_rules`, `recurring_occurrences` |
| 3 | 03 (feita) | `budgets` |
| 4 | 03 (feita) | `savings_goals`, `debts`, `debt_payments` |

A migração v1 → v4 foi validada num emulador Android com dados da fase
anterior: `user_version` passou a 4, tabelas novas criadas e contas,
categorias e movimentos preservados.

Regras do processo:

1. Nunca recriar a base para atualizar; nunca apagar dados para migrar.
2. Cada passo é aditivo e testado com dados existentes (abrir v1, aplicar v2,
   verificar preservação).
3. Cada novo passo insere a linha correspondente em `schema_migrations`.
4. Alterações ao esquema atualizam este documento no mesmo commit.

## Testes que cobrem este modelo

`test/unit/database/migration_test.dart`, `constraints_test.dart`,
`seeds_test.dart`, `test/unit/settings/app_settings_repository_test.dart`,
`test/unit/repositories/account_repository_test.dart`,
`test/unit/repositories/category_repository_test.dart`,
`test/unit/repositories/transaction_repository_test.dart`,
`test/unit/planning/planning_domain_test.dart`,
`test/unit/repositories/planning_repository_test.dart`,
`test/unit/repositories/budget_repository_test.dart`,
`test/unit/repositories/savings_goal_repository_test.dart`,
`test/unit/repositories/debt_repository_test.dart`,
`test/unit/repositories/allocation_integrity_test.dart` e
`test/widget/planning_flow_test.dart`.
