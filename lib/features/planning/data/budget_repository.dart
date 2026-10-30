import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart' as db;
import '../../../core/errors/app_failure.dart';
import '../../../core/utils/id.dart';
import '../../../core/utils/time.dart';
import '../domain/budget.dart';

/// Orçamentos mensais por categoria. O gasto é agregado em SQL a partir dos
/// movimentos reais de despesa do mês; transferências e rendimentos nunca
/// entram, porque o filtro exige `kind = 'expense'` e `category_id` igual.
class BudgetRepository {
  BudgetRepository(this._db);

  final db.AppDatabase _db;

  Stream<List<Budget>> watchMonth(DateTime month) {
    return _monthQuery(month).watch().map(_toBudgets);
  }

  Future<List<Budget>> readMonth(DateTime month) async {
    final rows = await _monthQuery(month).get();
    return _toBudgets(rows);
  }

  Selectable<QueryRow> _monthQuery(DateTime month) {
    const sql = '''
SELECT b.id, b.category_id, b.period_start, b.limit_amount,
       c.name AS category_name, c.is_archived AS category_archived,
       COALESCE((
         SELECT SUM(t.amount)
         FROM transactions t
         WHERE t.category_id = b.category_id
           AND t.kind = 'expense'
           AND t.deleted_at IS NULL
           AND t.transaction_date >= b.period_start
           AND t.transaction_date < date(b.period_start, '+1 month')
       ), 0) AS spent
FROM budgets b
JOIN categories c ON c.id = b.category_id
WHERE b.period_type = 'monthly' AND b.period_start = ?
ORDER BY c.name COLLATE NOCASE
''';
    return _db.customSelect(
      sql,
      variables: [Variable.withString(BudgetPeriod.dbValue(month))],
      readsFrom: {_db.budgets, _db.categories, _db.transactions},
    );
  }

  List<Budget> _toBudgets(List<QueryRow> rows) => rows
      .map(
        (row) => Budget(
          id: row.read<String>('id'),
          categoryId: row.read<String>('category_id'),
          categoryName: row.read<String>('category_name'),
          periodStart:
              DateTime.tryParse(row.read<String>('period_start')) ??
              DateTime(1970, 1, 1),
          limitAmount: row.read<int>('limit_amount'),
          spent: row.read<int>('spent'),
          categoryArchived: row.read<bool>('category_archived'),
        ),
      )
      .toList(growable: false);

  /// Cria ou atualiza o limite da categoria para o mês. A chave única
  /// `(category_id, period_type, period_start)` é garantida pelo esquema.
  Future<String> save(BudgetDraft draft) async {
    _ensureValid(draft.validate());
    final categoryId = draft.categoryId!;
    await _requireExpenseCategory(categoryId);
    final periodStart = BudgetPeriod.dbValue(draft.periodStart);

    return _db.transaction(() async {
      final existing =
          await (_db.select(_db.budgets)..where(
                (t) =>
                    t.categoryId.equals(categoryId) &
                    t.periodType.equals('monthly') &
                    t.periodStart.equals(periodStart),
              ))
              .getSingleOrNull();
      final now = utcNowIsoString();
      if (existing != null) {
        await (_db.update(
          _db.budgets,
        )..where((t) => t.id.equals(existing.id))).write(
          db.BudgetsCompanion(
            limitAmount: Value(draft.limitAmount),
            updatedAt: Value(now),
          ),
        );
        return existing.id;
      }
      final id = newId();
      await _db
          .into(_db.budgets)
          .insert(
            db.BudgetsCompanion.insert(
              id: id,
              categoryId: categoryId,
              periodStart: periodStart,
              limitAmount: draft.limitAmount,
              createdAt: now,
              updatedAt: now,
            ),
          );
      return id;
    });
  }

  Future<void> remove(String id) async {
    await (_db.delete(_db.budgets)..where((t) => t.id.equals(id))).go();
  }

  Future<void> _requireExpenseCategory(String id) async {
    final row = await (_db.select(
      _db.categories,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) {
      throw const AppFailure('Categoria inválida.');
    }
    if (row.kind != 'expense') {
      throw const AppFailure('Os orçamentos aplicam-se a despesas.');
    }
    if (row.isArchived) {
      throw const AppFailure('A categoria está arquivada.');
    }
  }

  void _ensureValid(Map<String, String> errors) {
    if (errors.isNotEmpty) {
      throw AppFailure(errors.values.first);
    }
  }
}
