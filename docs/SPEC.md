# Especificação — Aplicação de Finanças Pessoais

**Versão:** 1.0 | **Plataforma:** Flutter/Dart | **Persistência:** SQLite local | **Utilização:** individual | **Moeda inicial:** XOF/FCFA.

## 1. Visão e objetivos
Aplicação mobile offline-first para registar rendimentos, despesas, transferências, orçamentos, compromissos, metas e dívidas pessoais, com previsão local do saldo. Os dados ficam no dispositivo. Sincronização cloud não faz parte desta versão.

## 2. Fora do âmbito inicial
Gestão empresarial/multiempresa; utilizadores partilhados; integração bancária; pagamentos reais; armazenamento de credenciais bancárias; backend/API; Laravel/PHP/MySQL; Python/FastAPI; sincronização remota; treino de ML; aconselhamento financeiro garantido.

## 3. Requisitos funcionais
- **Contas:** dinheiro, banco, carteira móvel, poupança e outro; saldo inicial, data e moeda. Evitar guardar números bancários completos.
- **Categorias:** tipos rendimento/despesa; predefinidas e personalizadas; arquivar se referenciadas.
- **Movimentos:** rendimento, despesa e transferência; montante inteiro positivo; data, conta, categoria aplicável, descrição/notas opcionais.
- **Transferências:** uma operação lógica atómica entre duas contas distintas; não contar como rendimento/despesa.
- **Compromissos:** rendimentos/despesas futuros com vencimento e estado; compromisso pago associa-se a movimento real e não pode ser contado duas vezes.
- **Recorrências:** semanal, mensal e anual; ocorrências idempotentes.
- **Orçamentos:** limite mensal por categoria; gasto, restante e percentagem; excluir transferências.
- **Metas de poupança:** alvo, data opcional e progresso; não são despesas por si mesmas.
- **Dívidas:** a pagar/a receber, valor original, saldo pendente e pagamentos reais.
- **Painel:** saldos, rendimentos/despesas por período, orçamentos, próximos compromissos e previsão.
- **Relatórios:** por período, categoria e conta; exportação CSV. PDF pode ficar para versão futura.
- **Backup:** exportável e versionado; validar antes de restaurar; pedir confirmação e preservar dados atuais antes de substituição. Pode ser cifrado com frase-passe (AES-256-GCM, chave PBKDF2) ou simples; a leitura de backups simples anteriores é obrigatória e a frase-passe nunca é guardada.
- **Lembretes:** notificações locais opcionais, sem rede, na véspera e no dia do vencimento de compromissos em aberto e um resumo mensal de orçamentos excedidos; permissão pedida apenas ao ativar.
- **Privacidade:** nenhum envio de dados na versão inicial; sem analytics/ads. PIN/biometria só com APIs seguras adequadas; bloqueio de UI não significa cifragem da base. A cifra dos backups protege ficheiros exportados, não a base SQLite em uso.

## 4. Modelo SQLite
IDs recomendados: UUID em `TEXT`, para facilitar eventual sincronização futura. Datas financeiras `YYYY-MM-DD`; timestamps ISO-8601 UTC. Montantes em inteiros FCFA.

### `accounts`
`id TEXT PRIMARY KEY`, `name TEXT NOT NULL`, `type TEXT NOT NULL`, `currency_code TEXT NOT NULL DEFAULT 'XOF'`, `opening_balance INTEGER NOT NULL DEFAULT 0`, `opening_date TEXT NOT NULL`, `is_archived INTEGER NOT NULL DEFAULT 0`, `created_at TEXT NOT NULL`, `updated_at TEXT NOT NULL`.

### `categories`
`id TEXT PRIMARY KEY`, `name TEXT NOT NULL`, `kind TEXT NOT NULL` (`income`/`expense`), `icon_key TEXT NULL`, `color_value INTEGER NULL`, `is_system INTEGER NOT NULL DEFAULT 0`, `is_archived INTEGER NOT NULL DEFAULT 0`, `created_at TEXT NOT NULL`, `updated_at TEXT NOT NULL`. Criar índices para consultas e evitar nomes duplicados ativos por tipo quando possível.

### `transactions`
`id TEXT PRIMARY KEY`, `kind TEXT NOT NULL` (`income`/`expense`/`transfer`), `account_id TEXT NOT NULL REFERENCES accounts(id)`, `destination_account_id TEXT NULL REFERENCES accounts(id)`, `category_id TEXT NULL REFERENCES categories(id)`, `amount INTEGER NOT NULL CHECK(amount > 0)`, `transaction_date TEXT NOT NULL`, `description TEXT NULL`, `notes TEXT NULL`, `created_at TEXT NOT NULL`, `updated_at TEXT NOT NULL`, `deleted_at TEXT NULL` apenas se existir política explícita de eliminação lógica. Índices por data, conta, categoria e tipo. `destination_account_id` obrigatório apenas em transferências; origem e destino devem ser diferentes.

### `planned_items`
`id TEXT PRIMARY KEY`, `kind TEXT NOT NULL` (`income`/`expense`), `account_id TEXT NULL REFERENCES accounts(id)`, `category_id TEXT NULL REFERENCES categories(id)`, `amount INTEGER NOT NULL CHECK(amount > 0)`, `due_date TEXT NOT NULL`, `description TEXT NOT NULL`, `status TEXT NOT NULL` (`planned`, `partially_paid`, `paid`, `cancelled`), `transaction_id TEXT NULL REFERENCES transactions(id)`, `created_at TEXT NOT NULL`, `updated_at TEXT NOT NULL`.

### `recurring_rules`
`id TEXT PRIMARY KEY`, `kind TEXT NOT NULL`, `account_id TEXT NULL REFERENCES accounts(id)`, `category_id TEXT NULL REFERENCES categories(id)`, `amount INTEGER NOT NULL CHECK(amount > 0)`, `frequency TEXT NOT NULL` (`weekly`, `monthly`, `yearly`), `start_date TEXT NOT NULL`, `end_date TEXT NULL`, `next_occurrence_date TEXT NOT NULL`, `description TEXT NOT NULL`, `is_active INTEGER NOT NULL DEFAULT 1`, `created_at TEXT NOT NULL`, `updated_at TEXT NOT NULL`.

### `recurring_occurrences`
`id TEXT PRIMARY KEY`, `rule_id TEXT NOT NULL REFERENCES recurring_rules(id)`, `occurrence_date TEXT NOT NULL`, `planned_item_id TEXT NULL REFERENCES planned_items(id)`, `transaction_id TEXT NULL REFERENCES transactions(id)`, `status TEXT NOT NULL`, `created_at TEXT NOT NULL`, `UNIQUE(rule_id, occurrence_date)`.

### `budgets`
`id TEXT PRIMARY KEY`, `category_id TEXT NOT NULL REFERENCES categories(id)`, `period_type TEXT NOT NULL DEFAULT 'monthly'`, `period_start TEXT NOT NULL`, `limit_amount INTEGER NOT NULL CHECK(limit_amount >= 0)`, `created_at TEXT NOT NULL`, `updated_at TEXT NOT NULL`, `UNIQUE(category_id, period_type, period_start)`.

### `savings_goals`
`id TEXT PRIMARY KEY`, `name TEXT NOT NULL`, `target_amount INTEGER NOT NULL CHECK(target_amount > 0)`, `target_date TEXT NULL`, `linked_account_id TEXT NULL REFERENCES accounts(id)`, `notes TEXT NULL`, `is_archived INTEGER NOT NULL DEFAULT 0`, `created_at TEXT NOT NULL`, `updated_at TEXT NOT NULL`.

### `debts`
`id TEXT PRIMARY KEY`, `kind TEXT NOT NULL` (`payable`/`receivable`), `counterparty TEXT NULL`, `description TEXT NOT NULL`, `original_amount INTEGER NOT NULL CHECK(original_amount > 0)`, `due_date TEXT NULL`, `status TEXT NOT NULL`, `created_at TEXT NOT NULL`, `updated_at TEXT NOT NULL`.

### `debt_payments`
`id TEXT PRIMARY KEY`, `debt_id TEXT NOT NULL REFERENCES debts(id)`, `transaction_id TEXT NOT NULL REFERENCES transactions(id)`, `amount INTEGER NOT NULL CHECK(amount > 0)`, `payment_date TEXT NOT NULL`, `created_at TEXT NOT NULL`. Incluir quando se implementar liquidação detalhada.

### `app_settings`
`key TEXT PRIMARY KEY`, `value TEXT NOT NULL`, `updated_at TEXT NOT NULL`.

### `schema_migrations`
`version INTEGER PRIMARY KEY`, `applied_at TEXT NOT NULL`.

Ativar foreign keys em cada abertura da ligação. Usar transações SQLite para operações compostas e consultas parametrizadas. As tabelas podem ser entregues faseadamente, mas a especificação deve ser mantida e as migrações documentadas.

## 5. Regras de saldo
Saldo da conta = saldo inicial + rendimentos + créditos de transferências − despesas − débitos de transferências, até à data escolhida. Saldo consolidado só soma contas na mesma moeda. Compromissos futuros não alteram saldo realizado. Correções retroativas recalculam relatórios/previsões. Nunca contar compromisso e movimento de pagamento como dois movimentos de caixa.

## 6. Arquitetura proposta
```text
lib/
  main.dart
  app/ (app.dart, router.dart, theme/)
  core/ (database/, migrations/, errors/, formatters/, backup/, security/, utils/)
  features/
    dashboard/{data,domain,presentation}/
    accounts/{data,domain,presentation}/
    categories/{data,domain,presentation}/
    transactions/{data,domain,presentation}/
    budgets/{data,domain,presentation}/
    recurring/{data,domain,presentation}/
    planning/{data,domain,presentation}/
    savings/{data,domain,presentation}/
    debts/{data,domain,presentation}/
    forecast/{data,domain,presentation}/
    reports/{data,domain,presentation}/
    settings/{data,domain,presentation}/
test/{unit,widget,integration}/
docs/
```
Escolher uma biblioteca SQLite (por exemplo Drift ou sqflite) e uma solução de estado (por exemplo Riverpod ou Bloc) após verificar compatibilidade. Não misturar opções sem motivo. Widgets não devem conter SQL ou lógica financeira.

## 7. Previsão
Primeira versão Dart, determinística e explicável:
1. calcular saldo real na data de corte;
2. aplicar compromissos conhecidos e ocorrências recorrentes uma única vez;
3. estimar movimentos não planeados por média/mediana histórica apenas quando houver histórico suficiente;
4. se não houver histórico suficiente, mostrar apenas compromissos conhecidos e informar a limitação;
5. horizontes iniciais 7, 30 e 90 dias;
6. mostrar data de cálculo, pressupostos, cobertura de dados, menor saldo previsto e alertas de possível saldo negativo.
Não chamar regras simples de “IA” nem prometer precisão.

Evolução futura: comparar baseline com modelos como média sazonal/suavização exponencial, por backtesting temporal rolling-origin sem leakage. Considerar MAE/WAPE e as limitações quando valores reais são zero. Só adotar modelos avançados se melhorarem resultados em dados suficientes. Serviço externo exigiria nova decisão e consentimento explícito.

## 8. Requisitos não funcionais
- Fluxos essenciais funcionam sem internet.
- Operações financeiras atómicas e migrações seguras.
- Privacidade por defeito; sem tráfego financeiro de rede.
- Interface acessível e legível em Android modestos.
- Backups versionados e restauráveis.
- Código testável, separado por camadas e documentado.

## 9. Critérios globais de aceitação
1. App funciona em modo avião após instalação.
2. Contas, rendimentos, despesas e transferências são registáveis.
3. Saldos batem com casos de teste.
4. Transferências não aparecem como rendimento/despesa consolidada.
5. Orçamentos excluem transferências.
6. Compromissos não afetam saldo real antes de pagos.
7. Pagamento não gera dupla contagem.
8. Recorrências idempotentes.
9. Previsões exibem horizonte, data de corte, pressupostos e limitações.
10. Backup/restauração validado em teste.
11. Migrações preservam dados existentes.
12. `dart format`, `flutter analyze` e `flutter test` executados e resultados reportados.
13. Sem backend obrigatório nem chamadas de rede no fluxo principal.
14. Documentação de privacidade, backup, restauração e limitações da previsão.
