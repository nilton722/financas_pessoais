import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart' as db;
import '../../../core/errors/app_failure.dart';
import '../../../core/formatters/date_formatter.dart';
import '../../../core/utils/id.dart';
import '../../../core/utils/time.dart';
import '../domain/movement.dart';

class TransactionRepository {
  TransactionRepository(this._db);

  final db.AppDatabase _db;

  Stream<List<MovementListItem>> watchMovements(MovementFilter filter) {
    return _movementsQuery(filter)
        .watch()
        .map((rows) => rows.map(_toListItem).toList(growable: false));
  }

  /// Leitura pontual, sem subscrição contínua.
  Future<List<MovementListItem>> readMovements(MovementFilter filter) async {
    final rows = await _movementsQuery(filter).get();
    return rows.map(_toListItem).toList(growable: false);
  }

  Selectable<QueryRow> _movementsQuery(MovementFilter filter) {
    final conditions = <String>['t.deleted_at IS NULL'];
    final variables = <Variable>[];

    if (filter.from != null) {
      conditions.add('t.transaction_date >= ?');
      variables.add(
        Variable.withString(FinancialDate.fromDateTime(filter.from!)),
      );
    }
    if (filter.to != null) {
      conditions.add('t.transaction_date <= ?');
      variables.add(
        Variable.withString(FinancialDate.fromDateTime(filter.to!)),
      );
    }
    if (filter.kind != null) {
      conditions.add('t.kind = ?');
      variables.add(Variable.withString(filter.kind!.dbValue));
    }
    if (filter.categoryId != null) {
      conditions.add('t.category_id = ?');
      variables.add(Variable.withString(filter.categoryId!));
    }
    if (filter.accountId != null) {
      conditions.add('(t.account_id = ? OR t.destination_account_id = ?)');
      variables
        ..add(Variable.withString(filter.accountId!))
        ..add(Variable.withString(filter.accountId!));
    }

    final sql =
        '''
SELECT t.id, t.kind, t.account_id, t.destination_account_id, t.category_id,
       t.amount, t.transaction_date, t.description, t.notes, t.deleted_at,
       a.name AS account_name,
       d.name AS destination_name,
       c.name AS category_name
FROM transactions t
JOIN accounts a ON a.id = t.account_id
LEFT JOIN accounts d ON d.id = t.destination_account_id
LEFT JOIN categories c ON c.id = t.category_id
WHERE ${conditions.join(' AND ')}
ORDER BY t.transaction_date DESC, t.created_at DESC
''';

    return _db.customSelect(
      sql,
      variables: variables,
      readsFrom: {_db.transactions, _db.accounts, _db.categories},
    );
  }

  Future<Movement?> findById(String id) async {
    final row = await (_db.select(
      _db.transactions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  Future<String> createMovement(MovementDraft draft) async {
    _ensureValid(draft.validate());
    await _requireActiveAccount(draft.accountId);
    await _requireCategory(draft.categoryId, draft.kind);

    final id = newId();
    final now = utcNowIsoString();
    await _db
        .into(_db.transactions)
        .insert(
          db.TransactionsCompanion.insert(
            id: id,
            kind: draft.kind.dbValue,
            accountId: draft.accountId!,
            categoryId: Value(draft.categoryId),
            amount: draft.amount,
            transactionDate: FinancialDate.fromDateTime(draft.date),
            description: Value(_nullIfBlank(draft.description)),
            notes: Value(_nullIfBlank(draft.notes)),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  /// A transferência é um único registo lógico e uma operação atómica:
  /// validações de contas acontecem dentro da mesma transação SQLite, pelo
  /// que uma falha não deixa movimentos parciais.
  Future<String> createTransfer(TransferDraft draft) async {
    _ensureValid(draft.validate());
    return _db.transaction(() async {
      final source = await _requireActiveAccount(draft.sourceAccountId);
      final destination = await _requireActiveAccount(
        draft.destinationAccountId,
      );
      if (source.id == destination.id) {
        throw const AppFailure(
          'A conta de origem e destino têm de ser diferentes.',
        );
      }
      if (source.currencyCode != destination.currencyCode) {
        throw const AppFailure(
          'A transferência exige contas com a mesma moeda.',
        );
      }

      final id = newId();
      final now = utcNowIsoString();
      await _db
          .into(_db.transactions)
          .insert(
            db.TransactionsCompanion.insert(
              id: id,
              kind: MovementKind.transfer.dbValue,
              accountId: source.id,
              destinationAccountId: Value(destination.id),
              amount: draft.amount,
              transactionDate: FinancialDate.fromDateTime(draft.date),
              description: Value(_nullIfBlank(draft.description)),
              createdAt: now,
              updatedAt: now,
            ),
          );
      return id;
    });
  }

  Future<void> updateMovement(String id, MovementDraft draft) async {
    _ensureValid(draft.validate());
    await _db.transaction(() async {
      final existing = await _requireExisting(id);
      if (existing.kind == MovementKind.transfer.dbValue) {
        throw const AppFailure(
          'Um movimento de transferência não pode ser convertido.',
        );
      }
      await _requireActiveAccount(
        draft.accountId,
        allowArchivedId: existing.accountId,
      );
      await _requireCategory(
        draft.categoryId,
        draft.kind,
        allowArchivedId: existing.categoryId,
      );
      await _syncAllocationsAfterEdit(id, draft);
      await (_db.update(_db.transactions)..where((t) => t.id.equals(id))).write(
        db.TransactionsCompanion(
          accountId: Value(draft.accountId!),
          categoryId: Value(draft.categoryId),
          amount: Value(draft.amount),
          transactionDate: Value(FinancialDate.fromDateTime(draft.date)),
          description: Value(_nullIfBlank(draft.description)),
          notes: Value(_nullIfBlank(draft.notes)),
          updatedAt: Value(utcNowIsoString()),
        ),
      );
    });
  }

  Future<void> updateTransfer(String id, TransferDraft draft) async {
    _ensureValid(draft.validate());
    final existing = await _requireExisting(id);
    if (existing.kind != MovementKind.transfer.dbValue) {
      throw const AppFailure('Este registo não é uma transferência.');
    }
    await _db.transaction(() async {
      final source = await _requireActiveAccount(
        draft.sourceAccountId,
        allowArchivedId: existing.accountId,
      );
      final destination = await _requireActiveAccount(
        draft.destinationAccountId,
        allowArchivedId: existing.destinationAccountId,
      );
      if (source.id == destination.id) {
        throw const AppFailure(
          'A conta de origem e destino têm de ser diferentes.',
        );
      }
      if (source.currencyCode != destination.currencyCode) {
        throw const AppFailure(
          'A transferência exige contas com a mesma moeda.',
        );
      }
      await (_db.update(_db.transactions)..where((t) => t.id.equals(id))).write(
        db.TransactionsCompanion(
          accountId: Value(source.id),
          destinationAccountId: Value(destination.id),
          amount: Value(draft.amount),
          transactionDate: Value(FinancialDate.fromDateTime(draft.date)),
          description: Value(_nullIfBlank(draft.description)),
          updatedAt: Value(utcNowIsoString()),
        ),
      );
    });
  }

  /// Eliminação lógica: o registo deixa de contar para saldos e listas mas
  /// permanece na base para auditoria. Se o movimento liquidava um
  /// compromisso ou dívida, a alocação é removida e o estado é recalculado
  /// dentro da mesma transação, para não deixar saldos pendentes incoerentes.
  Future<void> softDelete(String id) async {
    await _db.transaction(() async {
      final existing = await _requireExisting(id);
      if (existing.deletedAt != null) {
        return;
      }
      final now = utcNowIsoString();
      await (_db.update(_db.transactions)..where((t) => t.id.equals(id))).write(
        db.TransactionsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );

      final planned = await _findPlannedPayment(id);
      if (planned != null) {
        await (_db.delete(
          _db.plannedItemPayments,
        )..where((t) => t.id.equals(planned.id))).go();
        await _refreshPlannedItem(planned.plannedItemId);
      }
      final debt = await _findDebtPayment(id);
      if (debt != null) {
        await (_db.delete(
          _db.debtPayments,
        )..where((t) => t.id.equals(debt.id))).go();
        await _refreshDebt(debt.debtId);
      }
    });
  }

  /// Mantém a alocação coerente quando um movimento associado é editado. O
  /// total alocado nunca pode exceder o valor do compromisso ou da dívida;
  /// a data do movimento acompanha a data da alocação.
  Future<void> _syncAllocationsAfterEdit(
    String transactionId,
    MovementDraft draft,
  ) async {
    final planned = await _findPlannedPayment(transactionId);
    if (planned != null) {
      final item = await _requirePlannedItemRow(planned.plannedItemId);
      if (draft.kind.dbValue != item.kind) {
        throw const AppFailure(
          'O movimento está associado a um compromisso de outro tipo.',
        );
      }
      final paid = await _plannedPaidTotal(item.id);
      final newTotal = paid - planned.amount + draft.amount;
      if (newTotal > item.amount) {
        throw const AppFailure('O novo valor excede o compromisso associado.');
      }
      await (_db.update(
        _db.plannedItemPayments,
      )..where((t) => t.id.equals(planned.id))).write(
        db.PlannedItemPaymentsCompanion(
          amount: Value(draft.amount),
          paymentDate: Value(FinancialDate.fromDateTime(draft.date)),
        ),
      );
      await _refreshPlannedItem(item.id);
    }

    final debt = await _findDebtPayment(transactionId);
    if (debt != null) {
      final row = await _requireDebtRow(debt.debtId);
      final kind = MovementKind.fromDb(
        row.kind == 'payable' ? 'expense' : 'income',
      );
      if (draft.kind != kind) {
        throw const AppFailure(
          'O movimento está associado a uma dívida de outro tipo.',
        );
      }
      final paid = await _debtPaidTotal(row.id);
      final newTotal = paid - debt.amount + draft.amount;
      if (newTotal > row.originalAmount) {
        throw const AppFailure('O novo valor excede a dívida associada.');
      }
      await (_db.update(
        _db.debtPayments,
      )..where((t) => t.id.equals(debt.id))).write(
        db.DebtPaymentsCompanion(
          amount: Value(draft.amount),
          paymentDate: Value(FinancialDate.fromDateTime(draft.date)),
        ),
      );
      await _refreshDebt(row.id);
    }
  }

  Future<db.PlannedItemPayment?> _findPlannedPayment(String transactionId) {
    return (_db.select(
      _db.plannedItemPayments,
    )..where((t) => t.transactionId.equals(transactionId))).getSingleOrNull();
  }

  Future<db.DebtPayment?> _findDebtPayment(String transactionId) {
    return (_db.select(
      _db.debtPayments,
    )..where((t) => t.transactionId.equals(transactionId))).getSingleOrNull();
  }

  Future<db.PlannedItem> _requirePlannedItemRow(String id) async {
    final row = await (_db.select(
      _db.plannedItems,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) {
      throw const AppFailure('Compromisso associado não encontrado.');
    }
    return row;
  }

  Future<db.Debt> _requireDebtRow(String id) async {
    final row = await (_db.select(
      _db.debts,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) {
      throw const AppFailure('Dívida associada não encontrada.');
    }
    return row;
  }

  Future<int> _plannedPaidTotal(String itemId) async {
    const sql = '''
SELECT COALESCE(SUM(pay.amount), 0) AS total
FROM planned_item_payments pay
JOIN transactions t ON t.id = pay.transaction_id
WHERE pay.planned_item_id = ? AND t.deleted_at IS NULL
''';
    final row = await _db
        .customSelect(sql, variables: [Variable.withString(itemId)])
        .getSingle();
    return row.read<int>('total');
  }

  Future<int> _debtPaidTotal(String debtId) async {
    const sql = '''
SELECT COALESCE(SUM(p.amount), 0) AS total
FROM debt_payments p
JOIN transactions t ON t.id = p.transaction_id
WHERE p.debt_id = ? AND t.deleted_at IS NULL
''';
    final row = await _db
        .customSelect(sql, variables: [Variable.withString(debtId)])
        .getSingle();
    return row.read<int>('total');
  }

  Future<void> _refreshPlannedItem(String itemId) async {
    final item = await _requirePlannedItemRow(itemId);
    final paid = await _plannedPaidTotal(itemId);
    final isCancelled = item.status == 'cancelled';
    final status = isCancelled
        ? 'cancelled'
        : (paid >= item.amount
              ? 'paid'
              : (paid > 0 ? 'partially_paid' : 'planned'));
    String? transactionId;
    if (status == 'paid') {
      transactionId = await _latestPlannedPaymentTransaction(itemId);
    }
    final now = utcNowIsoString();
    await (_db.update(
      _db.plannedItems,
    )..where((t) => t.id.equals(itemId))).write(
      db.PlannedItemsCompanion(
        status: Value(status),
        transactionId: Value(transactionId),
        updatedAt: Value(now),
      ),
    );
    await (_db.update(
      _db.recurringOccurrences,
    )..where((t) => t.plannedItemId.equals(itemId))).write(
      db.RecurringOccurrencesCompanion(
        status: Value(
          status == 'cancelled'
              ? 'cancelled'
              : (status == 'paid' ? 'paid' : 'planned'),
        ),
        transactionId: Value(status == 'paid' ? transactionId : null),
      ),
    );
  }

  Future<void> _refreshDebt(String debtId) async {
    final debt = await _requireDebtRow(debtId);
    final paid = await _debtPaidTotal(debtId);
    final status = debt.status == 'cancelled'
        ? 'cancelled'
        : (paid >= debt.originalAmount ? 'paid' : 'open');
    await (_db.update(_db.debts)..where((t) => t.id.equals(debtId))).write(
      db.DebtsCompanion(
        status: Value(status),
        updatedAt: Value(utcNowIsoString()),
      ),
    );
  }

  Future<String?> _latestPlannedPaymentTransaction(String itemId) async {
    final row =
        await (_db.select(_db.plannedItemPayments)
              ..where((t) => t.plannedItemId.equals(itemId))
              ..orderBy([(t) => OrderingTerm.desc(t.paymentDate)])
              ..limit(1))
            .getSingleOrNull();
    return row?.transactionId;
  }

  Future<db.Account> _requireActiveAccount(
    String? id, {
    String? allowArchivedId,
  }) async {
    if (id == null || id.isEmpty) {
      throw const AppFailure('Escolha uma conta.');
    }
    final row = await (_db.select(
      _db.accounts,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) {
      throw const AppFailure('Conta inválida.');
    }
    if (row.isArchived && row.id != allowArchivedId) {
      throw const AppFailure('A conta está arquivada.');
    }
    return row;
  }

  Future<db.Category> _requireCategory(
    String? id,
    MovementKind kind, {
    String? allowArchivedId,
  }) async {
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
    if (row.isArchived && row.id != allowArchivedId) {
      throw const AppFailure('A categoria está arquivada.');
    }
    return row;
  }

  Future<db.Transaction> _requireExisting(String id) async {
    final row = await (_db.select(
      _db.transactions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) {
      throw const AppFailure('Movimento não encontrado.');
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

  Movement _toDomain(db.Transaction row) => Movement(
    id: row.id,
    kind: MovementKind.fromDb(row.kind),
    accountId: row.accountId,
    destinationAccountId: row.destinationAccountId,
    categoryId: row.categoryId,
    amount: row.amount,
    date: FinancialDate.tryParse(row.transactionDate) ?? DateTime(1970, 1, 1),
    description: row.description,
    notes: row.notes,
    deletedAt: _parseTimestamp(row.deletedAt),
  );

  MovementListItem _toListItem(QueryRow row) => MovementListItem(
    movement: Movement(
      id: row.read<String>('id'),
      kind: MovementKind.fromDb(row.read<String>('kind')),
      accountId: row.read<String>('account_id'),
      destinationAccountId: row.readNullable<String>('destination_account_id'),
      categoryId: row.readNullable<String>('category_id'),
      amount: row.read<int>('amount'),
      date:
          FinancialDate.tryParse(row.read<String>('transaction_date')) ??
          DateTime(1970, 1, 1),
      description: row.readNullable<String>('description'),
      notes: row.readNullable<String>('notes'),
      deletedAt: _parseTimestamp(row.readNullable<String>('deleted_at')),
    ),
    accountName: row.read<String>('account_name'),
    destinationAccountName: row.readNullable<String>('destination_name'),
    categoryName: row.readNullable<String>('category_name'),
  );

  DateTime? _parseTimestamp(String? value) =>
      value == null ? null : DateTime.tryParse(value)?.toUtc();
}
