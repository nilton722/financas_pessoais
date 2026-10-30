import 'package:drift/drift.dart';

/// v3: orçamentos mensais por categoria.
abstract final class SchemaV3 {
  static const int version = 3;

  static const List<String> statements = [
    'CREATE INDEX IF NOT EXISTS idx_budgets_period '
        'ON budgets(period_type, period_start)',
  ];

  static Future<void> apply(GeneratedDatabase db, {DateTime? appliedAt}) async {
    for (final statement in statements) {
      await db.customStatement(statement);
    }
    await db.customStatement(
      'INSERT OR IGNORE INTO schema_migrations(version, applied_at) '
      'VALUES (?, ?)',
      [version, (appliedAt ?? DateTime.now()).toUtc().toIso8601String()],
    );
  }
}
