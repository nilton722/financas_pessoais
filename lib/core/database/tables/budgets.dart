import 'package:drift/drift.dart';

import 'categories.dart';

/// Limite mensal por categoria. O gasto nunca é guardado: é calculado a
/// partir das despesas reais, excluindo transferências e registos eliminados.
class Budgets extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text().references(Categories, #id)();
  TextColumn get periodType => text().withDefault(const Constant('monthly'))();
  TextColumn get periodStart => text()();
  IntColumn get limitAmount => integer()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    "CHECK (period_type IN ('monthly'))",
    'CHECK (limit_amount >= 0)',
    "CHECK (period_start GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-01')",
    'UNIQUE (category_id, period_type, period_start)',
    "CHECK (created_at GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*Z')",
    "CHECK (updated_at GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*Z')",
  ];
}
