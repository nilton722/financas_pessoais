import 'package:drift/drift.dart';

/// v2: compromissos futuros, alocações de pagamento e recorrências.
abstract final class SchemaV2 {
  static const int version = 2;

  static const List<String> statements = [
    'CREATE INDEX IF NOT EXISTS idx_planned_items_due_date '
        'ON planned_items(due_date)',
    'CREATE INDEX IF NOT EXISTS idx_planned_items_status '
        'ON planned_items(status)',
    'CREATE INDEX IF NOT EXISTS idx_planned_item_payments_item '
        'ON planned_item_payments(planned_item_id)',
    'CREATE INDEX IF NOT EXISTS idx_recurring_rules_active '
        'ON recurring_rules(is_active)',
    'CREATE INDEX IF NOT EXISTS idx_recurring_occurrences_rule '
        'ON recurring_occurrences(rule_id)',
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
