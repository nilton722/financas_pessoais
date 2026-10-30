import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart' as db;
import '../../../core/errors/app_failure.dart';
import '../../../core/formatters/date_formatter.dart';
import '../../../core/utils/id.dart';
import '../../../core/utils/time.dart';
import '../domain/debt.dart';

/// Dívidas a pagar e a receber. O saldo pendente resulta sempre dos
/// pagamentos reais (movimentos não eliminados); criar uma dívida não mexe
/// no caixa e pagar cria exatamente um movimento.
class DebtRepository {
  DebtRepository(this._db);

  final db.AppDatabase _db;

  Stream<List<Debt>> watchDebts({bool openOnly = false}) {
    return _debtsQuery(openOnly: openOnly).watch().map(_toDebts);
  }

  Future<List<Debt>> readDebts({bool openOnly = false}) async {
    final rows = await _debtsQuery(openOnly: openOnly).get();
    return _toDebts(rows);
  }

  Future<Debt?> findById(String id) async {
    final rows = await _debtsQuery(debtId: id).get();
    return rows.isEmpty ? null : _toDebt(rows.first);
  }

  Selectable<QueryRow> _debtsQuery({bool openOnly = false, String? debtId}) {
    final conditions = <String>[];
    final variables = <Variable>[];
    if (openOnly) {
      conditions.add("d.status = 'open'");
    }
    if (debtId != null) {
      conditions.add('d.id = ?');
      variables.add(Variable.withString(debtId));
    }
    final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    final sql =
        '''
SELECT d.id, d.kind, d.counterparty, d.description, d.original_amount,
       d.due_date, d.status,
       COALESCE((
         SELECT SUM(p.amount)
         FROM debt_payments p
         JOIN transactions t ON t.id = p.transaction_id
         WHERE p.debt_id = d.id AND t.deleted_at IS NULL
       ), 0) AS paid_total
FROM debts d
$where
ORDER BY CASE WHEN d.status = 'open' THEN 0 ELSE 1 END,
         COALESCE(d.due_date, '9999-12-31') ASC,
         d.created_at DESC
''';
    return _db.customSelect(
      sql,
      variables: variables,
      readsFrom: {_db.debts, _db.debtPayments, _db.transactions},
    );
  }

  List<Debt> _toDebts(List<QueryRow> rows) =>
      rows.map(_toDebt).toList(growable: false);

  Debt _toDebt(QueryRow row) => Debt(
    id: row.read<String>('id'),
    kind: DebtKind.fromDb(row.read<String>('kind')),
    counterparty: row.readNullable<String>('counterparty'),
    description: row.read<String>('description'),
    originalAmount: row.read<int>('original_amount'),
    dueDate: _parseDate(row.readNullable<String>('due_date')),
    status: DebtStatus.fromDb(row.read<String>('status')),
    paidTotal: row.read<int>('paid_total'),
  );

  Future<String> create(DebtDraft draft) async {
    _ensureValid(draft.validate());
    final id = newId();
    final now = utcNowIsoString();
    await _db
        .into(_db.debts)
        .insert(
          db.DebtsCompanion.insert(
            id: id,
            kind: draft.kind.dbValue,
            counterparty: Value(_nullIfBlank(draft.counterparty)),
            description: draft.description.trim(),
            originalAmount: draft.originalAmount,
            dueDate: Value(_dateOrNull(draft.dueDate)),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<void> update(String id, DebtDraft draft) async {
    _ensureValid(draft.validate());
    final existing = await _requireDebtRow(id);
    if (existing.status == DebtStatus.cancelled.dbValue) {
      throw const AppFailure('Uma dívida cancelada não pode ser editada.');
    }
    final paidTotal = await _paidTotal(id);
    if (paidTotal >= existing.originalAmount) {
      throw const AppFailure(
        'Uma dívida liquidada não pode ser editada. '
        'Elimine os movimentos para a reverter.',
      );
    }
    if (draft.originalAmount < paidTotal) {
      throw const AppFailure('O valor não pode ser inferior ao total já pago.');
    }
    final status = paidTotal >= draft.originalAmount
        ? DebtStatus.paid
        : DebtStatus.open;
    await (_db.update(_db.debts)..where((t) => t.id.equals(id))).write(
      db.DebtsCompanion(
        kind: Value(draft.kind.dbValue),
        counterparty: Value(_nullIfBlank(draft.counterparty)),
        description: Value(draft.description.trim()),
        originalAmount: Value(draft.originalAmount),
        dueDate: Value(_dateOrNull(draft.dueDate)),
        status: Value(status.dbValue),
        updatedAt: Value(utcNowIsoString()),
      ),
    );
  }

  Future<void> cancel(String id) async {
    final existing = await _requireDebtRow(id);
    if (existing.status == DebtStatus.cancelled.dbValue) {
      return;
    }
    final paidTotal = await _paidTotal(id);
    if (paidTotal >= existing.originalAmount) {
      throw const AppFailure(
        'Uma dívida liquidada não pode ser cancelada. '
        'Elimine os movimentos para a reverter.',
      );
    }
    await (_db.update(_db.debts)..where((t) => t.id.equals(id))).write(
      db.DebtsCompanion(
        status: Value(DebtStatus.cancelled.dbValue),
        updatedAt: Value(utcNowIsoString()),
      ),
    );
  }

  Stream<List<DebtPayment>> watchPayments(String debtId) {
    return _paymentsQuery(debtId)
        .watch()
        .map((rows) => rows.map(_toPayment).toList(growable: false));
  }

  Future<List<DebtPayment>> readPayments(String debtId) async {
    final rows = await _paymentsQuery(debtId).get();
    return rows.map(_toPayment).toList(growable: false);
  }

  Selectable<QueryRow> _paymentsQuery(String debtId) {
    const sql = '''
SELECT p.id, p.debt_id, p.transaction_id, p.amount, p.payment_date,
       t.description
FROM debt_payments p
JOIN transactions t ON t.id = p.transaction_id
WHERE p.debt_id = ? AND t.deleted_at IS NULL
ORDER BY p.payment_date DESC, p.created_at DESC
''';
    return _db.customSelect(
      sql,
      variables: [Variable.withString(debtId)],
      readsFrom: {_db.debtPayments, _db.transactions},
    );
  }

  DebtPayment _toPayment(QueryRow row) => DebtPayment(
    id: row.read<String>('id'),
    debtId: row.read<String>('debt_id'),
    transactionId: row.read<String>('transaction_id'),
    amount: row.read<int>('amount'),
    date:
        FinancialDate.tryParse(row.read<String>('payment_date')) ??
        DateTime(1970, 1, 1),
    description: row.readNullable<String>('description'),
  );

  /// Regista um pagamento real da dívida. O total liquidado nunca excede o
  /// valor original; o movimento e a alocação são criados atomicamente.
  Future<String> pay(String id, DebtPaymentDraft draft) async {
    return _db.transaction(() async {
      final existing = await _requireDebtRow(id);
      if (existing.status == DebtStatus.cancelled.dbValue) {
        throw const AppFailure('Uma dívida cancelada não pode ser paga.');
      }
      final paidTotal = await _paidTotal(id);
      final remaining = existing.originalAmount - paidTotal;
      _ensureValid(draft.validate(remaining: remaining));

      final debtKind = DebtKind.fromDb(existing.kind);
      final account = await _requireActiveAccount(draft.accountId);
      final category = await _requireCategory(
        draft.categoryId,
        debtKind.movementKind,
      );
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
              kind: debtKind.movementKind,
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
          .into(_db.debtPayments)
          .insert(
            db.DebtPaymentsCompanion.insert(
              id: newId(),
              debtId: id,
              transactionId: transactionId,
              amount: draft.amount,
              paymentDate: paymentDate,
              createdAt: now,
            ),
          );
      final newPaid = paidTotal + draft.amount;
      if (newPaid >= existing.originalAmount) {
        await (_db.update(_db.debts)..where((t) => t.id.equals(id))).write(
          db.DebtsCompanion(
            status: Value(DebtStatus.paid.dbValue),
            updatedAt: Value(now),
          ),
        );
      }
      return transactionId;
    });
  }

  Future<db.Debt> _requireDebtRow(String id) async {
    final row = await (_db.select(
      _db.debts,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) {
      throw const AppFailure('Dívida não encontrada.');
    }
    return row;
  }

  Future<int> _paidTotal(String id) async {
    const sql = '''
SELECT COALESCE(SUM(p.amount), 0) AS total
FROM debt_payments p
JOIN transactions t ON t.id = p.transaction_id
WHERE p.debt_id = ? AND t.deleted_at IS NULL
''';
    final row = await _db
        .customSelect(sql, variables: [Variable.withString(id)])
        .getSingle();
    return row.read<int>('total');
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

  Future<db.Category> _requireCategory(String? id, String kind) async {
    if (id == null || id.isEmpty) {
      throw const AppFailure('Escolha uma categoria.');
    }
    final row = await (_db.select(
      _db.categories,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) {
      throw const AppFailure('Categoria inválida.');
    }
    if (row.kind != kind) {
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
