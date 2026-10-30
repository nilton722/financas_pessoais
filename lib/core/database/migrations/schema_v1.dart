import 'package:drift/drift.dart';

/// Esquema inicial (v1): contas, categorias, movimentos, configurações
/// e registo de migrações. As restantes tabelas da SPEC entram na v2 (ver
/// `docs/DATABASE.md`).
abstract final class SchemaV1 {
  static const int version = 1;

  static const List<String> statements = [
    'CREATE INDEX IF NOT EXISTS idx_transactions_date '
        'ON transactions(transaction_date)',
    'CREATE INDEX IF NOT EXISTS idx_transactions_account '
        'ON transactions(account_id)',
    'CREATE INDEX IF NOT EXISTS idx_transactions_category '
        'ON transactions(category_id)',
    'CREATE INDEX IF NOT EXISTS idx_transactions_kind ON transactions(kind)',
    'CREATE UNIQUE INDEX IF NOT EXISTS uq_categories_active_name '
        'ON categories(kind, name) WHERE is_archived = 0',
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
