# Registo de decisões arquiteturais (ADR)

## ADR-001 — Flutter/Dart
**Estado:** aceite. Flutter/Dart será a plataforma mobile principal, Android primeiro e arquitetura preparada para iOS. Não usar React web como interface principal nesta versão.

## ADR-002 — SQLite local
**Estado:** aceite. SQLite é a fonte de verdade local, permitindo operação offline e sem custos de servidor. Não há sincronização ou recuperação remota nesta versão.

## ADR-003 — Sincronização futura, não agora
**Estado:** aceite. Usar IDs UUID e camadas de repositório para facilitar evolução, sem criar API/backend nem campos de conflito prematuros. Sincronização futura exige novo desenho de conflitos, autenticação, segurança e consentimento.

## ADR-004 — Montantes inteiros
**Estado:** aceite. Guardar FCFA/XOF como inteiros; nunca usar `double` em cálculos monetários.

## ADR-005 — Datas
**Estado:** aceite. Datas financeiras `YYYY-MM-DD`; timestamps técnicos ISO-8601 UTC. Apresentação `DD/MM/YYYY`; `Africa/Bissau` inicial e configurável.

## ADR-006 — Previsão local
**Estado:** aceite. Começar com regras Dart transparentes e compromissos conhecidos. Sem Python, ML ou IA externa na primeira versão. Mostrar limitações e não garantir resultados.

## ADR-007 — Compromissos versus movimentos
**Estado:** aceite. Planeamentos ficam separados das transações realizadas; pagamento associa-se ao compromisso para evitar dupla contagem.

## ADR-008 — Transferências neutras
**Estado:** aceite. Transferências próprias alteram duas contas, mas não são rendimento/despesa. Operação atómica.

## ADR-009 — Migrações e backup
**Estado:** aceite. Migrações incrementais e versionadas; backup versionado, validado e restaurável. Nunca apagar a base para atualizar.

## ADR-010 — Privacidade
**Estado:** aceite. Sem telemetria, anúncios ou envio de dados por defeito. Cualquier sincronização futura requer decisão explícita, consentimento e segurança apropriada.

## ADR-011 — Testes
**Estado:** aceite. Testes unitários de domínio, SQLite/repositórios, migrações, widgets e integração dos fluxos críticos. Reportar resultados reais.

## ADR-012 — Modelos estatísticos futuros
**Estado:** aceite. Evoluir só após baseline, dados suficientes e backtesting temporal sem leakage. Comparar MAE/WAPE com baseline e não afirmar superioridade sem evidência.

## ADR-013 — Drift como biblioteca SQLite
**Estado:** aceite na Fase 01. `drift` 2.35.3 com `drift_dev`/`build_runner`.
Motivo: schema tipado, migrações versionadas com testes, foreign keys e transações integradas, e `NativeDatabase.memory()` para testes rápidos do SQL real. Também corre em desktop, o que permite validar a app fora de um emulador. Alternativa `sqflite` 2.4.5 rejeitada: SQL manual, migrações sem tipagem e testes em desktop exigiriam `sqflite_common_ffi`.
Consequência: passo obrigatório de codegen (`dart run build_runner build`) ao alterar tabelas; `lib/core/database/app_database.g.dart` é gerado e não editado à mão. `sqlite3_flutter_libs` está EOL e não é usado; `sqlite3` 3.x resolve a biblioteca nativa por native assets.

## ADR-014 — Riverpod para estado
**Estado:** aceite na Fase 01. `flutter_riverpod` 3.4.3 sem codegen.
Motivo: providers pequenos e testáveis, injeção trivial da base em testes (`ProviderScope` overrides) e ausência de mais uma camada de geração de código. Bloc rejeitado por boilerplate desproporcionado para uma app individual.

## ADR-015 — Entrega faseada do esquema SQLite
**Estado:** aceite na Fase 01. A migração v1 cria `accounts`, `categories`, `transactions`, `app_settings` e `schema_migrations`. As restantes tabelas da SPEC entram em v2–v4 conforme `docs/DATABASE.md`.
Motivo: respeitar o âmbito por fase sem divergir da especificação, exercitando migrações incrementais reais em vez de criar estruturas inúteis durante várias fases.

## ADR-016 — Eliminação lógica de movimentos
**Estado:** aceite na Fase 01. `transactions.deleted_at TEXT NULL` faz parte da v1. Registos com `deleted_at` preenchido ficam fora de saldos, orçamentos e relatórios e não são apagados fisicamente.
Motivo: a Fase 02 exige que eliminação lógica recalcule saldos; introduzir a coluna agora evita um `ALTER TABLE` imediato e fixa a política desde o início.

## ADR-017 — go_router com ShellRoute
**Estado:** aceite na Fase 02; atualizado na Fase 03 com o quinto separador. `go_router` 18.1.1 com `ShellRoute` e `NavigationBar` (Painel, Movimentos, Contas, Categorias, Planeamento); formulários são rotas próprias (`/accounts/new`, `/movements/:id/edit`, `/categories/…`, `/planning/commitments/:id/pay`, `/planning/budgets/new`, …).
Motivo: separadores persistentes com uma única árvore de navegação, URLs testáveis e `push`/`pop` previsíveis nos formulários. `MaterialApp.home` (Fase 01) deixou de servir assim que existiram rotas reais; a dependência entrou apenas quando passou a ser usada. O planeamento é uma área única com cinco entradas (compromissos, orçamentos, recorrências, metas e dívidas) para não sobrecarregar a barra inferior.

## ADR-018 — Saldos calculados, nunca armazenados
**Estado:** aceite na Fase 02. O saldo de uma conta é sempre saldo inicial + movimentos não eliminados até à data de referência, agregados em SQL e somados no domínio (`AccountBalance`, `consolidatedBalance`).
Motivo: eliminar ou editar um movimento recalcula tudo sem migração de dados nem risco de saldo divergente do histórico. Transferências entre contas próprias anulam-se por construção. Custo aceite: agregação em cada leitura, coberta pelos índices de `transactions` e adequada à escala de uma app individual. Se o volume crescer, a otimização será materializar saldos com verificação de consistência, nunca passar a ser a fonte de verdade.
Consequência técnica: os repositórios expõem `watch*` (streams) e `read*` (leitura pontual); o Drift reentrega o último resultado em cache ao re-subserver a mesma consulta, pelo que leituras pontuais após escrita usam `read*`, não `stream.first`.

## ADR-019 — Compromissos pagos por alocação explícita
**Estado:** aceite na Fase 03. Pagar um compromisso cria um movimento real (`expense`/`income`) e uma linha em `planned_item_payments`, na mesma transação SQLite. `UNIQUE(transaction_id)` impede que o mesmo movimento conte em dois compromissos; a soma das alocações nunca excede o valor do compromisso. O estado e o valor pago são derivados do total alocado a movimentos não eliminados, não de uma coluna mutável.
Motivo: cumprir "pagamento não duplica caixa" e "parciais não excedem o valor" sem depender de sincronização posterior. Pagamentos parciais são explícitos e auditáveis; cancelar o compromisso remove-o da previsão mas preserva os movimentos já pagos. O compromisso nunca altera saldo — só o movimento criado no pagamento o faz (ADR-007).

## ADR-020 — Recorrências ancoradas no início e ocorrências idempotentes
**Estado:** aceite na Fase 03. Regras semanal/mensal/anual calculam datas a partir de `start_date`, com ajuste ao último dia em meses curtos (31 Jan → 28/29 Fev → 31 Mar). `syncRecurrences` materializa compromissos até um horizonte (90 dias na UI) e `UNIQUE(rule_id, occurrence_date)` garante idempotência mesmo com execuções repetidas.
Motivo: evita saltos de dia e duplicação de ocorrências. A sincronização corre ao abrir o planeamento e no botão de atualização; falhas mostram `AppFailure` sem bloquear a lista. Depois de existirem ocorrências, alterar tipo, frequência ou início é rejeitado — evita reinterpretar ocorrências já materializadas; valor, descrição, conta, categoria e fim continuam editáveis.

## ADR-021 — Integridade entre movimentos e alocações
**Estado:** aceite na Fase 03. Editar ou eliminar um movimento alocado atualiza a alocação correspondente e o estado do compromisso/dívida na mesma transação: o novo total não pode ficar abaixo do já pago nem acima do valor; eliminar remove a alocação e reabre o compromisso/dívida; ocorrências de recorrência voltam a `planned`. Sem pagamentos, cancelar um compromisso preserva a previsão (nada é apagado).
Motivo: sem isto, saldos e estados divergiriam e a app poderia mostrar dívida paga com movimento eliminado, ou permitir pagar duas vezes o mesmo valor. As validações vivem no repositório porque dependem de agregações entre tabelas.

## ADR-022 — Orçamentos calculados em SQL
**Estado:** aceite na Fase 03. O orçamento guarda apenas o limite mensal por categoria; o gasto é `SUM(amount)` de movimentos `expense` não eliminados no intervalo `[period_start, +1 month)`. Transferências e rendimentos ficam de fora. `UNIQUE(category_id, period_type, period_start)` transforma "criar" em upsert do limite.
Motivo: um valor de gasto guardado dessincronizaria ao editar/eliminar movimentos. O cálculo reutiliza os índices de `transactions` e a mesma política de eliminação lógica. O mês corrente é o único apresentado na Fase 03, com navegação para meses anteriores/seguintes.

## ADR-023 — Metas de poupança medidas pelo saldo real
**Estado:** aceite na Fase 03. Uma meta tem alvo, data opcional e conta associada opcional; o progresso é o saldo atual dessa conta (calculado por `AccountRepository`), nunca um valor introduzido nem uma despesa.
Motivo: evita dupla contagem e mantém uma única regra de saldo (ADR-018). Sem conta associada, o progresso é zero e a meta funciona como objetivo abstrato. Arquivar apenas oculta a meta; conta e movimentos ficam intactos.

## ADR-024 — Dívidas liquidadas por pagamentos reais
**Estado:** aceite na Fase 03. O pendente de uma dívida é o valor original menos os pagamentos cujo movimento não está eliminado. Cada liquidação cria exatamente um movimento (`expense` para dívida a pagar, `income` para dívida a receber) e uma linha em `debt_payments` (`UNIQUE(transaction_id)`), nunca excedendo o pendente. Dívida cancelada ou liquidada não aceita novos pagamentos.
Motivo: o caixa só muda com dinheiro real; o estado deriva dos pagamentos, pelo que eliminar um movimento reabre a dívida de forma consistente. O cancelamento mantém os movimentos já feitos e apenas retira a dívida da lista de pendentes.

## ADR-025 — Alertas locais apenas dentro da app
**Estado:** aceite na Fase 03. O planeamento mostra alertas derivados dos streams: compromissos vencidos ou a vencer em 7 dias, dívidas vencidas e orçamentos excedidos. Não há plugin de notificações do sistema, nem agendamento em background.
Motivo: cumprir "alertas locais opcionais" sem novas dependências nem pedidos de permissão, mantendo tudo offline e privado. Os alertas desaparecem assim que o estado muda, porque usam os mesmos providers das listas.
