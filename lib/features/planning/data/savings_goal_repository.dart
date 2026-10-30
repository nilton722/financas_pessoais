import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart' as db;
import '../../../core/errors/app_failure.dart';
import '../../../core/formatters/date_formatter.dart';
import '../../../core/utils/id.dart';
import '../../../core/utils/time.dart';
import '../../accounts/data/account_repository.dart';
import '../domain/savings_goal.dart';

/// Metas de poupança. O progresso reaproveita o cálculo de saldo das contas
/// (`AccountRepository`), pelo que uma meta nunca é tratada como despesa: só
/// os movimentos reais alteram o saldo da conta associada.
class SavingsGoalRepository {
  SavingsGoalRepository(this._db) : _accounts = AccountRepository(_db);

  final db.AppDatabase _db;
  final AccountRepository _accounts;

  Stream<List<SavingsGoal>> watchAll({bool includeArchived = false}) {
    return _goalsQuery(includeArchived: includeArchived)
        .watch()
        .asyncMap(_withBalances);
  }

  Future<List<SavingsGoal>> readAll({bool includeArchived = false}) async {
    final rows = await _goalsQuery(includeArchived: includeArchived).get();
    return _withBalances(rows);
  }

  Future<SavingsGoal?> findById(String id) async {
    final rows = await _goalsQuery(goalId: id).get();
    if (rows.isEmpty) {
      return null;
    }
    final goals = await _withBalances(rows);
    return goals.first;
  }

  Selectable<QueryRow> _goalsQuery({
    bool includeArchived = false,
    String? goalId,
  }) {
    final conditions = <String>[];
    final variables = <Variable>[];
    if (!includeArchived) {
      conditions.add('g.is_archived = 0');
    }
    if (goalId != null) {
      conditions.add('g.id = ?');
      variables.add(Variable.withString(goalId));
    }
    final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    final sql =
        '''
SELECT g.id, g.name, g.target_amount, g.target_date, g.linked_account_id,
       g.notes, g.is_archived,
       a.name AS account_name
FROM savings_goals g
LEFT JOIN accounts a ON a.id = g.linked_account_id
$where
ORDER BY g.is_archived ASC, COALESCE(g.target_date, '9999-12-31') ASC,
         g.name COLLATE NOCASE
''';
    return _db.customSelect(
      sql,
      variables: variables,
      readsFrom: {
        _db.savingsGoals,
        _db.accounts,
        // Movimentos alteram o saldo da conta associada.
        _db.transactions,
      },
    );
  }

  Future<List<SavingsGoal>> _withBalances(List<QueryRow> rows) async {
    final balances = await _accounts.readBalances(
      until: FinancialDate.today(),
      includeArchived: true,
    );
    final balanceByAccount = {
      for (final entry in balances) entry.account.id: entry.balance,
    };
    return rows
        .map((row) {
          final linkedAccountId = row.readNullable<String>('linked_account_id');
          return SavingsGoal(
            id: row.read<String>('id'),
            name: row.read<String>('name'),
            targetAmount: row.read<int>('target_amount'),
            currentAmount: linkedAccountId == null
                ? 0
                : (balanceByAccount[linkedAccountId] ?? 0),
            isArchived: row.read<bool>('is_archived'),
            targetDate: _parseDate(row.readNullable<String>('target_date')),
            linkedAccountId: linkedAccountId,
            linkedAccountName: row.readNullable<String>('account_name'),
            notes: row.readNullable<String>('notes'),
          );
        })
        .toList(growable: false);
  }

  Future<String> create(SavingsGoalDraft draft) async {
    _ensureValid(draft.validate());
    await _validateAccount(draft.linkedAccountId);
    final id = newId();
    final now = utcNowIsoString();
    await _db
        .into(_db.savingsGoals)
        .insert(
          db.SavingsGoalsCompanion.insert(
            id: id,
            name: draft.name.trim(),
            targetAmount: draft.targetAmount,
            targetDate: Value(_dateOrNull(draft.targetDate)),
            linkedAccountId: Value(_nullIfBlank(draft.linkedAccountId)),
            notes: Value(_nullIfBlank(draft.notes)),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<void> update(String id, SavingsGoalDraft draft) async {
    _ensureValid(draft.validate());
    await _requireGoal(id);
    await _validateAccount(draft.linkedAccountId);
    await (_db.update(_db.savingsGoals)..where((t) => t.id.equals(id))).write(
      db.SavingsGoalsCompanion(
        name: Value(draft.name.trim()),
        targetAmount: Value(draft.targetAmount),
        targetDate: Value(_dateOrNull(draft.targetDate)),
        linkedAccountId: Value(_nullIfBlank(draft.linkedAccountId)),
        notes: Value(_nullIfBlank(draft.notes)),
        updatedAt: Value(utcNowIsoString()),
      ),
    );
  }

  Future<void> setArchived(String id, {required bool archived}) async {
    await _requireGoal(id);
    await (_db.update(_db.savingsGoals)..where((t) => t.id.equals(id))).write(
      db.SavingsGoalsCompanion(
        isArchived: Value(archived),
        updatedAt: Value(utcNowIsoString()),
      ),
    );
  }

  Future<void> _validateAccount(String? accountId) async {
    final id = _nullIfBlank(accountId);
    if (id == null) {
      return;
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
  }

  Future<void> _requireGoal(String id) async {
    final row = await (_db.select(
      _db.savingsGoals,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) {
      throw const AppFailure('Meta não encontrada.');
    }
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
