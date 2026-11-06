import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart' as db;
import '../../../core/errors/app_failure.dart';
import '../../../core/formatters/date_formatter.dart';
import '../../../core/utils/id.dart';
import '../../../core/utils/time.dart';
import '../domain/planned_item.dart';
import '../domain/recurrence.dart';

/// Compromissos futuros, pagamentos e recorrências. Os compromissos nunca
/// alteram saldos: só os movimentos reais criados ao pagar contam para o
/// caixa. Todas as operações compostas correm numa transação SQLite.
class PlanningRepository {
  PlanningRepository(this._db);

  final db.AppDatabase _db;

  Stream<List<PlannedItem>> watchItems({bool pendingOnly = false}) {
    return _itemsQuery(pendingOnly: pendingOnly).watch().map(_toItems);
  }

  /// Leitura pontual, sem subscrição contínua.
  Future<List<PlannedItem>> readItems({bool pendingOnly = false}) async {
    final rows = await _itemsQuery(pendingOnly: pendingOnly).get();
    return _toItems(rows);
  }

  Future<PlannedItem?> findItem(String id) async {
    final rows = await _itemsQuery(itemId: id).get();
    return rows.isEmpty ? null : _toItem(rows.first);
  }

  Selectable<QueryRow> _itemsQuery({bool pendingOnly = false, String? itemId}) {
    final conditions = <String>[];
    final variables = <Variable>[];
    if (pendingOnly) {
      conditions.add("p.status IN ('planned', 'partially_paid')");
    }
    if (itemId != null) {
      conditions.add('p.id = ?');
      variables.add(Variable.withString(itemId));
    }
    final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    final sql =
        '''
SELECT p.id, p.kind, p.account_id, p.category_id, p.amount, p.due_date,
       p.description, p.status, p.transaction_id,
       a.name AS account_name,
       c.name AS category_name,
       COALESCE((
         SELECT SUM(pay.amount)
         FROM planned_item_payments pay
         JOIN transactions tx ON tx.id = pay.transaction_id
         WHERE pay.planned_item_id = p.id AND tx.deleted_at IS NULL
       ), 0) AS paid_total
FROM planned_items p
LEFT JOIN accounts a ON a.id = p.account_id
LEFT JOIN categories c ON c.id = p.category_id
$where
ORDER BY p.due_date ASC, p.created_at ASC
''';
    return _db.customSelect(
      sql,
      variables: variables,
      readsFrom: {
        _db.plannedItems,
        _db.plannedItemPayments,
        _db.transactions,
        _db.accounts,
        _db.categories,
      },
    );
  }

  List<PlannedItem> _toItems(List<QueryRow> rows) =>
      rows.map(_toItem).toList(growable: false);

  PlannedItem _toItem(QueryRow row) => PlannedItem(
    id: row.read<String>('id'),
    kind: PlannedItemKind.fromDb(row.read<String>('kind')),
    amount: row.read<int>('amount'),
    dueDate:
        FinancialDate.tryParse(row.read<String>('due_date')) ??
        DateTime(1970, 1, 1),
    description: row.read<String>('description'),
    status: PlannedItemStatus.fromDb(row.read<String>('status')),
    paidTotal: row.read<int>('paid_total'),
    accountId: row.readNullable<String>('account_id'),
    categoryId: row.readNullable<String>('category_id'),
    transactionId: row.readNullable<String>('transaction_id'),
    accountName: row.readNullable<String>('account_name'),
    categoryName: row.readNullable<String>('category_name'),
  );

  Future<String> createItem(PlannedItemDraft draft) async {
    _ensureValid(draft.validate());
    await _validateRefs(
      kind: draft.kind,
      accountId: draft.accountId,
      categoryId: draft.categoryId,
    );

    final id = newId();
    final now = utcNowIsoString();
    await _db
        .into(_db.plannedItems)
        .insert(
          db.PlannedItemsCompanion.insert(
            id: id,
            kind: draft.kind.dbValue,
            accountId: Value(_nullIfBlank(draft.accountId)),
            categoryId: Value(_nullIfBlank(draft.categoryId)),
            amount: draft.amount,
            dueDate: FinancialDate.fromDateTime(draft.dueDate),
            description: draft.description.trim(),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<void> updateItem(String id, PlannedItemDraft draft) async {
    _ensureValid(draft.validate());
    final existing = await _requireItemRow(id);
    if (existing.status == PlannedItemStatus.cancelled.dbValue) {
      throw const AppFailure('Um compromisso cancelado não pode ser editado.');
    }
    final paidTotal = await _paidTotal(id);
    if (paidTotal >= existing.amount) {
      throw const AppFailure(
        'Um compromisso liquidado não pode ser editado. '
        'Elimine o movimento para o reverter.',
      );
    }
    if (draft.amount < paidTotal) {
      throw const AppFailure('O valor não pode ser inferior ao total já pago.');
    }
    await _validateRefs(
      kind: draft.kind,
      accountId: draft.accountId,
      categoryId: draft.categoryId,
    );

    final becomesPaid = paidTotal >= draft.amount;
    final status = becomesPaid
        ? PlannedItemStatus.paid
        : (paidTotal > 0
              ? PlannedItemStatus.partiallyPaid
              : PlannedItemStatus.planned);
    String? transactionId;
    if (becomesPaid) {
      transactionId =
          await _latestPaymentTransaction(id) ?? existing.transactionId;
    }

    await (_db.update(_db.plannedItems)..where((t) => t.id.equals(id))).write(
      db.PlannedItemsCompanion(
        kind: Value(draft.kind.dbValue),
        accountId: Value(_nullIfBlank(draft.accountId)),
        categoryId: Value(_nullIfBlank(draft.categoryId)),
        amount: Value(draft.amount),
        dueDate: Value(FinancialDate.fromDateTime(draft.dueDate)),
        description: Value(draft.description.trim()),
        status: Value(status.dbValue),
        transactionId: Value(transactionId),
        updatedAt: Value(utcNowIsoString()),
      ),
    );
  }

  /// Cancelar retira o compromisso da previsão sem tocar em movimentos já
  /// realizados; um compromisso totalmente pago tem de ser revertido pelo
  /// movimento, não pelo estado.
  Future<void> cancelItem(String id) async {
    await _db.transaction(() async {
      final existing = await _requireItemRow(id);
      if (existing.status == PlannedItemStatus.cancelled.dbValue) {
        return;
      }
      final paidTotal = await _paidTotal(id);
      if (paidTotal >= existing.amount) {
        throw const AppFailure(
          'Um compromisso liquidado não pode ser cancelado. '
          'Elimine o movimento para o reverter.',
        );
      }
      final now = utcNowIsoString();
      await (_db.update(_db.plannedItems)..where((t) => t.id.equals(id))).write(
        db.PlannedItemsCompanion(
          status: Value(PlannedItemStatus.cancelled.dbValue),
          updatedAt: Value(now),
        ),
      );
      await (_db.update(_db.recurringOccurrences)
            ..where((t) => t.plannedItemId.equals(id)))
          .write(db.RecurringOccurrencesCompanion(status: Value('cancelled')));
    });
  }

  Stream<List<PlannedPayment>> watchPayments(String plannedItemId) {
    return _paymentsQuery(plannedItemId)
        .watch()
        .map((rows) => rows.map(_toPayment).toList(growable: false));
  }

  Future<List<PlannedPayment>> readPayments(String plannedItemId) async {
    final rows = await _paymentsQuery(plannedItemId).get();
    return rows.map(_toPayment).toList(growable: false);
  }

  Selectable<QueryRow> _paymentsQuery(String plannedItemId) {
    const sql = '''
SELECT pay.id, pay.planned_item_id, pay.transaction_id, pay.amount,
       pay.payment_date, t.description
FROM planned_item_payments pay
JOIN transactions t ON t.id = pay.transaction_id
WHERE pay.planned_item_id = ? AND t.deleted_at IS NULL
ORDER BY pay.payment_date DESC, pay.created_at DESC
''';
    return _db.customSelect(
      sql,
      variables: [Variable.withString(plannedItemId)],
      readsFrom: {_db.plannedItemPayments, _db.transactions},
    );
  }

  PlannedPayment _toPayment(QueryRow row) => PlannedPayment(
    id: row.read<String>('id'),
    plannedItemId: row.read<String>('planned_item_id'),
    transactionId: row.read<String>('transaction_id'),
    amount: row.read<int>('amount'),
    date:
        FinancialDate.tryParse(row.read<String>('payment_date')) ??
        DateTime(1970, 1, 1),
    description: row.readNullable<String>('description'),
  );

  /// Paga (total ou parcialmente) um compromisso, criando o movimento real
  /// na mesma transação. Devolve o id do movimento criado. O total alocado
  /// nunca excede o valor do compromisso.
  Future<String> payItem(String id, PaymentDraft draft) async {
    return _db.transaction(() async {
      final existing = await _requireItemRow(id);
      if (existing.status == PlannedItemStatus.cancelled.dbValue) {
        throw const AppFailure('Um compromisso cancelado não pode ser pago.');
      }
      final paidTotal = await _paidTotal(id);
      final remaining = existing.amount - paidTotal;
      _ensureValid(draft.validate(remaining: remaining));

      final kind = PlannedItemKind.fromDb(existing.kind);
      final account = await _requireActiveAccount(draft.accountId);
      final categoryId = _nullIfBlank(draft.categoryId) ?? existing.categoryId;
      final category = await _requireCategory(categoryId, kind);

      final description =
          _nullIfBlank(draft.description) ?? existing.description;
      final now = utcNowIsoString();
      final transactionId = newId();
      final paymentDate = FinancialDate.fromDateTime(draft.date);
      await _db
          .into(_db.transactions)
          .insert(
            db.TransactionsCompanion.insert(
              id: transactionId,
              kind: kind.dbValue,
              accountId: account.id,
              categoryId: Value(category.id),
              amount: draft.amount,
              transactionDate: paymentDate,
              description: Value(description),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _db
          .into(_db.plannedItemPayments)
          .insert(
            db.PlannedItemPaymentsCompanion.insert(
              id: newId(),
              plannedItemId: id,
              transactionId: transactionId,
              amount: draft.amount,
              paymentDate: paymentDate,
              createdAt: now,
            ),
          );

      final newPaid = paidTotal + draft.amount;
      final isPaid = newPaid >= existing.amount;
      await (_db.update(_db.plannedItems)..where((t) => t.id.equals(id))).write(
        db.PlannedItemsCompanion(
          status: Value(
            isPaid
                ? PlannedItemStatus.paid.dbValue
                : PlannedItemStatus.partiallyPaid.dbValue,
          ),
          transactionId: isPaid ? Value(transactionId) : const Value.absent(),
          updatedAt: Value(now),
        ),
      );
      await (_db.update(
        _db.recurringOccurrences,
      )..where((t) => t.plannedItemId.equals(id))).write(
        db.RecurringOccurrencesCompanion(
          status: Value(isPaid ? 'paid' : 'planned'),
          transactionId: Value(isPaid ? transactionId : null),
        ),
      );
      return transactionId;
    });
  }

  Stream<List<RecurringRule>> watchRules() {
    return _rulesQuery().watch().map(
      (rows) => rows.map(_toRule).toList(growable: false),
    );
  }

  Future<List<RecurringRule>> readRules() async {
    final rows = await _rulesQuery().get();
    return rows.map(_toRule).toList(growable: false);
  }

  Future<RecurringRule?> findRule(String id) async {
    final row = await _rulesQuery(ruleId: id).getSingleOrNull();
    return row == null ? null : _toRule(row);
  }

  Selectable<QueryRow> _rulesQuery({String? ruleId}) {
    final where = ruleId == null ? '' : 'WHERE r.id = ?';
    final sql =
        '''
SELECT r.id, r.kind, r.account_id, r.category_id, r.amount, r.frequency,
       r.start_date, r.end_date, r.next_occurrence_date, r.description,
       r.is_active,
       a.name AS account_name,
       c.name AS category_name
FROM recurring_rules r
LEFT JOIN accounts a ON a.id = r.account_id
LEFT JOIN categories c ON c.id = r.category_id
$where
ORDER BY r.is_active DESC, r.next_occurrence_date ASC, r.created_at ASC
''';
    return _db.customSelect(
      sql,
      variables: ruleId == null
          ? const <Variable>[]
          : [Variable.withString(ruleId)],
      readsFrom: {_db.recurringRules, _db.accounts, _db.categories},
    );
  }

  RecurringRule _toRule(QueryRow row) => RecurringRule(
    id: row.read<String>('id'),
    kind: PlannedItemKind.fromDb(row.read<String>('kind')),
    amount: row.read<int>('amount'),
    frequency: RecurrenceFrequency.fromDb(row.read<String>('frequency')),
    startDate:
        FinancialDate.tryParse(row.read<String>('start_date')) ??
        DateTime(1970, 1, 1),
    endDate: _parseDate(row.readNullable<String>('end_date')),
    nextOccurrenceDate:
        FinancialDate.tryParse(row.read<String>('next_occurrence_date')) ??
        DateTime(1970, 1, 1),
    description: row.read<String>('description'),
    isActive: row.read<bool>('is_active'),
    accountId: row.readNullable<String>('account_id'),
    categoryId: row.readNullable<String>('category_id'),
    accountName: row.readNullable<String>('account_name'),
    categoryName: row.readNullable<String>('category_name'),
  );

  Future<String> createRule(RecurringRuleDraft draft) async {
    _ensureValid(draft.validate());
    await _validateRefs(
      kind: draft.kind,
      accountId: draft.accountId,
      categoryId: draft.categoryId,
    );
    final id = newId();
    final now = utcNowIsoString();
    await _db
        .into(_db.recurringRules)
        .insert(
          db.RecurringRulesCompanion.insert(
            id: id,
            kind: draft.kind.dbValue,
            accountId: Value(_nullIfBlank(draft.accountId)),
            categoryId: Value(_nullIfBlank(draft.categoryId)),
            amount: draft.amount,
            frequency: draft.frequency.dbValue,
            startDate: FinancialDate.fromDateTime(draft.startDate),
            endDate: Value(_dateOrNull(draft.endDate)),
            nextOccurrenceDate: FinancialDate.fromDateTime(
              draft.initialNextOccurrence,
            ),
            description: draft.description.trim(),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  /// Editar a estrutura (tipo, frequência, início ou fim) reconstrói apenas
  /// as ocorrências futuras ainda sem pagamentos: as passadas e as que já
  /// receberam algum pagamento ficam intactas. Alterações de valor,
  /// descrição e referências propagam-se às ocorrências futuras planeadas,
  /// para que a próxima geração e os compromissos já criados fiquem
  /// coerentes com a regra.
  Future<void> updateRule(String id, RecurringRuleDraft draft) async {
    _ensureValid(draft.validate());
    await _db.transaction(() async {
      final existing = await _requireRuleRow(id);
      final startChanged =
          FinancialDate.fromDateTime(draft.startDate) != existing.startDate;
      final frequencyChanged = draft.frequency.dbValue != existing.frequency;
      final kindChanged = draft.kind.dbValue != existing.kind;
      final endChanged = _dateOrNull(draft.endDate) != existing.endDate;
      final structureChanged =
          startChanged || frequencyChanged || kindChanged || endChanged;
      await _validateRefs(
        kind: draft.kind,
        accountId: draft.accountId,
        categoryId: draft.categoryId,
      );

      final today = FinancialDate.today();
      final futureToRebuild = await _futureOccurrences(
        id,
        today.add(const Duration(days: 1)),
      );
      if (structureChanged) {
        for (final occurrence in futureToRebuild) {
          if (occurrence.isCancelled) {
            continue;
          }
          final item = await _findPlannedItemRow(occurrence.plannedItemId);
          if (item == null) {
            continue;
          }
          final paid = await _paidTotal(item.id);
          if (item.status == PlannedItemStatus.paid.dbValue ||
              item.status == PlannedItemStatus.partiallyPaid.dbValue ||
              paid > 0) {
            throw const AppFailure(
              'Existem ocorrências futuras com pagamentos. Conclui ou '
              'reverte esses pagamentos antes de alterar o tipo, a '
              'frequência, o início ou o fim.',
            );
          }
        }
        for (final occurrence in futureToRebuild) {
          if (occurrence.isCancelled) {
            continue;
          }
          await (_db.delete(
            _db.recurringOccurrences,
          )..where((t) => t.id.equals(occurrence.occurrenceId))).go();
          if (occurrence.plannedItemId != null) {
            await (_db.delete(
              _db.plannedItems,
            )..where((t) => t.id.equals(occurrence.plannedItemId!))).go();
          }
        }
      }

      final nextOccurrence = structureChanged
          ? await _firstAvailableOccurrence(
              id: id,
              frequency: draft.frequency,
              startDate: draft.startDate,
              endDate: draft.endDate,
              notBefore: today,
            )
          : null;
      await (_db.update(
        _db.recurringRules,
      )..where((t) => t.id.equals(id))).write(
        db.RecurringRulesCompanion(
          kind: Value(draft.kind.dbValue),
          accountId: Value(_nullIfBlank(draft.accountId)),
          categoryId: Value(_nullIfBlank(draft.categoryId)),
          amount: Value(draft.amount),
          frequency: Value(draft.frequency.dbValue),
          startDate: Value(FinancialDate.fromDateTime(draft.startDate)),
          endDate: Value(_dateOrNull(draft.endDate)),
          nextOccurrenceDate: nextOccurrence == null
              ? const Value.absent()
              : Value(FinancialDate.fromDateTime(nextOccurrence)),
          description: Value(draft.description.trim()),
          updatedAt: Value(utcNowIsoString()),
        ),
      );

      if (!structureChanged) {
        final pending = await _futureOccurrences(id, today);
        for (final occurrence in pending) {
          if (occurrence.isCancelled || occurrence.plannedItemId == null) {
            continue;
          }
          final item = await _findPlannedItemRow(occurrence.plannedItemId!);
          if (item == null ||
              item.status != PlannedItemStatus.planned.dbValue) {
            continue;
          }
          await (_db.update(
            _db.plannedItems,
          )..where((t) => t.id.equals(item.id))).write(
            db.PlannedItemsCompanion(
              kind: Value(draft.kind.dbValue),
              accountId: Value(_nullIfBlank(draft.accountId)),
              categoryId: Value(_nullIfBlank(draft.categoryId)),
              amount: Value(draft.amount),
              description: Value(draft.description.trim()),
              updatedAt: Value(utcNowIsoString()),
            ),
          );
        }
      }
    });
  }

  /// Ocorrências de uma regra a partir de hoje, com o item materializado.
  Future<List<_FutureOccurrence>> _futureOccurrences(
    String ruleId,
    DateTime from,
  ) async {
    final rows =
        await (_db.select(_db.recurringOccurrences)
              ..where(
                (t) =>
                    t.ruleId.equals(ruleId) &
                    t.occurrenceDate.isBiggerOrEqualValue(
                      FinancialDate.fromDateTime(from),
                    ),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.occurrenceDate)]))
            .get();
    return rows
        .map(
          (row) => _FutureOccurrence(
            occurrenceId: row.id,
            plannedItemId: row.plannedItemId,
            isCancelled: row.status == 'cancelled',
          ),
        )
        .toList(growable: false);
  }

  /// Primeira data da nova agenda que ainda não está materializada. Ignora
  /// datas anteriores a [notBefore] para não criar histórico retroativo ao
  /// mudar a frequência ou o início.
  Future<DateTime> _firstAvailableOccurrence({
    required String id,
    required RecurrenceFrequency frequency,
    required DateTime startDate,
    required DateTime? endDate,
    required DateTime notBefore,
  }) async {
    final floor = FinancialDate.dateOnly(notBefore);
    final end = endDate == null ? null : FinancialDate.dateOnly(endDate);
    for (var index = 0; index < 10000; index++) {
      final date = frequency.dateFor(startDate, index);
      if (date.isBefore(floor)) {
        continue;
      }
      if (end != null && date.isAfter(end)) {
        return date;
      }
      if (!await _occurrenceExists(id, date)) {
        return date;
      }
    }
    return floor;
  }

  Future<db.PlannedItem?> _findPlannedItemRow(String? id) async {
    if (id == null) {
      return null;
    }
    return (_db.select(
      _db.plannedItems,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> setRuleActive(String id, {required bool active}) async {
    await _requireRuleRow(id);
    await (_db.update(_db.recurringRules)..where((t) => t.id.equals(id))).write(
      db.RecurringRulesCompanion(
        isActive: Value(active),
        updatedAt: Value(utcNowIsoString()),
      ),
    );
  }

  /// Número de ocorrências já geradas; a edição de datas fica bloqueada a
  /// partir da primeira.
  Future<int> occurrenceCount(String ruleId) => _occurrenceCount(ruleId);

  /// Materializa as ocorrências ativas até [horizon] (inclusive). É
  /// idempotente: repetir a sincronização não cria duplicados, porque cada
  /// ocorrência é verificada por `(rule_id, occurrence_date)` antes de ser
  /// inserida e a tabela tem `UNIQUE` como última barreira.
  Future<int> syncRecurrences({
    required DateTime horizon,
    int maxPerRule = 500,
  }) async {
    final limit = FinancialDate.dateOnly(horizon);
    return _db.transaction(() async {
      var created = 0;
      final rules = await _db.select(_db.recurringRules).get();
      for (final rule in rules) {
        if (!rule.isActive) {
          continue;
        }
        final start = FinancialDate.tryParse(rule.startDate);
        var next = FinancialDate.tryParse(rule.nextOccurrenceDate);
        final end = _parseDate(rule.endDate);
        if (start == null || next == null) {
          continue;
        }
        if (end != null && next.isAfter(FinancialDate.dateOnly(end))) {
          continue;
        }
        final frequency = RecurrenceFrequency.fromDb(rule.frequency);
        var index = 0;
        while (frequency.dateFor(start, index).isBefore(next)) {
          index++;
          if (index > maxPerRule * 10) {
            break;
          }
        }
        var generated = 0;
        while (generated < maxPerRule) {
          final date = frequency.dateFor(start, index);
          if (date.isAfter(limit) ||
              (end != null && date.isAfter(FinancialDate.dateOnly(end)))) {
            break;
          }
          if (await _occurrenceExists(rule.id, date)) {
            index++;
            generated++;
            continue;
          }
          final now = utcNowIsoString();
          final itemId = newId();
          await _db
              .into(_db.plannedItems)
              .insert(
                db.PlannedItemsCompanion.insert(
                  id: itemId,
                  kind: rule.kind,
                  accountId: Value(rule.accountId),
                  categoryId: Value(rule.categoryId),
                  amount: rule.amount,
                  dueDate: FinancialDate.fromDateTime(date),
                  description: rule.description,
                  createdAt: now,
                  updatedAt: now,
                ),
              );
          await _db
              .into(_db.recurringOccurrences)
              .insert(
                db.RecurringOccurrencesCompanion.insert(
                  id: newId(),
                  ruleId: rule.id,
                  occurrenceDate: FinancialDate.fromDateTime(date),
                  plannedItemId: Value(itemId),
                  createdAt: now,
                ),
              );
          created++;
          index++;
          generated++;
        }
        if (generated > 0) {
          await (_db.update(
            _db.recurringRules,
          )..where((t) => t.id.equals(rule.id))).write(
            db.RecurringRulesCompanion(
              nextOccurrenceDate: Value(
                FinancialDate.fromDateTime(frequency.dateFor(start, index)),
              ),
              updatedAt: Value(utcNowIsoString()),
            ),
          );
        }
      }
      return created;
    });
  }

  Future<bool> _occurrenceExists(String ruleId, DateTime date) async {
    final row =
        await (_db.select(_db.recurringOccurrences)..where(
              (t) =>
                  t.ruleId.equals(ruleId) &
                  t.occurrenceDate.equals(FinancialDate.fromDateTime(date)),
            ))
            .getSingleOrNull();
    return row != null;
  }

  Future<int> _occurrenceCount(String ruleId) async {
    final count = _db.recurringOccurrences.id.count();
    final query = _db.selectOnly(_db.recurringOccurrences)
      ..addColumns([count])
      ..where(_db.recurringOccurrences.ruleId.equals(ruleId));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  Future<db.PlannedItem> _requireItemRow(String id) async {
    final row = await (_db.select(
      _db.plannedItems,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) {
      throw const AppFailure('Compromisso não encontrado.');
    }
    return row;
  }

  Future<db.RecurringRule> _requireRuleRow(String id) async {
    final row = await (_db.select(
      _db.recurringRules,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) {
      throw const AppFailure('Regra de recorrência não encontrada.');
    }
    return row;
  }

  Future<int> _paidTotal(String id) async {
    const sql = '''
SELECT COALESCE(SUM(pay.amount), 0) AS total
FROM planned_item_payments pay
JOIN transactions t ON t.id = pay.transaction_id
WHERE pay.planned_item_id = ? AND t.deleted_at IS NULL
''';
    final row = await _db
        .customSelect(sql, variables: [Variable.withString(id)])
        .getSingle();
    return row.read<int>('total');
  }

  Future<String?> _latestPaymentTransaction(String id) async {
    final row =
        await (_db.select(_db.plannedItemPayments)
              ..where((t) => t.plannedItemId.equals(id))
              ..orderBy([(t) => OrderingTerm.desc(t.paymentDate)])
              ..limit(1))
            .getSingleOrNull();
    return row?.transactionId;
  }

  Future<void> _validateRefs({
    required PlannedItemKind kind,
    required String? accountId,
    required String? categoryId,
  }) async {
    if (_nullIfBlank(accountId) != null) {
      await _requireActiveAccount(accountId);
    }
    if (_nullIfBlank(categoryId) != null) {
      await _requireCategory(categoryId, kind);
    }
  }

  Future<db.Account> _requireActiveAccount(String? id) async {
    if (id == null || id.isEmpty) {
      throw const AppFailure('Escolha uma conta.');
    }
    final row = await (_db.select(
      _db.accounts,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) {
      throw const AppFailure('Conta inválida.');
    }
    if (row.isArchived) {
      throw const AppFailure('A conta está arquivada.');
    }
    return row;
  }

  Future<db.Category> _requireCategory(String? id, PlannedItemKind kind) async {
    if (id == null || id.isEmpty) {
      throw const AppFailure('Escolha uma categoria.');
    }
    final row = await (_db.select(
      _db.categories,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) {
      throw const AppFailure('Categoria inválida.');
    }
    if (row.kind != kind.dbValue) {
      throw const AppFailure(
        'A categoria não corresponde ao tipo de movimento.',
      );
    }
    if (row.isArchived) {
      throw const AppFailure('A categoria está arquivada.');
    }
    return row;
  }

  void _ensureValid(Map<String, String> errors) {
    if (errors.isNotEmpty) {
      throw AppFailure(errors.values.first);
    }
  }

  String? _nullIfBlank(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  String? _dateOrNull(DateTime? value) =>
      value == null ? null : FinancialDate.fromDateTime(value);

  DateTime? _parseDate(String? value) =>
      value == null ? null : FinancialDate.tryParse(value);
}

class _FutureOccurrence {
  const _FutureOccurrence({
    required this.occurrenceId,
    required this.plannedItemId,
    required this.isCancelled,
  });

  final String occurrenceId;
  final String? plannedItemId;
  final bool isCancelled;
}
