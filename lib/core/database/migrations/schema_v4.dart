import 'package:drift/drift.dart';

/// v4: metas de poupança, dívidas e liquidações de dívida.
abstract final class SchemaV4 {
  static const int version = 4;

  static const List<String> statements = [
    'CREATE INDEX IF NOT EXISTS idx_savings_goals_archived '
        'ON savings_goals(is_archived)',
    'CREATE INDEX IF NOT EXISTS idx_debts_status ON debts(status)',
    'CREATE INDEX IF NOT EXISTS idx_debt_payments_debt '
        'ON debt_payments(debt_id)',
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
