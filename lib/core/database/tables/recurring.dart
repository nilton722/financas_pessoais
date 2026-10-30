import 'package:drift/drift.dart';

import 'accounts.dart';
import 'categories.dart';
import 'planned_items.dart';
import 'transactions.dart';

const recurrenceFrequencies = ['weekly', 'monthly', 'yearly'];
const recurrenceStatuses = ['planned', 'paid', 'cancelled'];

/// Regra de recorrência semanal, mensal ou anual. As datas são calculadas a
/// partir de `start_date`, para que o dia do mês não se perca nos meses
/// curtos (31 de janeiro continua a gerar dia 31 em março).
class RecurringRules extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  TextColumn get accountId => text().nullable().references(Accounts, #id)();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  IntColumn get amount => integer()();
  TextColumn get frequency => text()();
  TextColumn get startDate => text()();
  TextColumn get endDate => text().nullable()();
  TextColumn get nextOccurrenceDate => text()();
  TextColumn get description => text().withLength(min: 1)();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    "CHECK (kind IN ('income', 'expense'))",
    'CHECK (amount > 0)',
    "CHECK (frequency IN ('weekly', 'monthly', 'yearly'))",
    'CHECK (end_date IS NULL OR end_date >= start_date)',
    "CHECK (start_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]')",
    "CHECK (next_occurrence_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]')",
    "CHECK (end_date IS NULL OR end_date GLOB "
        "'[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]')",
    "CHECK (created_at GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*Z')",
    "CHECK (updated_at GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*Z')",
  ];
}

/// Ocorrência materializada de uma regra. `UNIQUE(rule_id, occurrence_date)`
/// torna a geração idempotente: repetir a sincronização não duplica nada.
class RecurringOccurrences extends Table {
  TextColumn get id => text()();
  TextColumn get ruleId => text().references(RecurringRules, #id)();
  TextColumn get occurrenceDate => text()();
  TextColumn get plannedItemId =>
      text().nullable().references(PlannedItems, #id)();
  TextColumn get transactionId =>
      text().nullable().references(Transactions, #id)();
  TextColumn get status => text().withDefault(const Constant('planned'))();
  TextColumn get createdAt => text()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'UNIQUE (rule_id, occurrence_date)',
    "CHECK (status IN ('planned', 'paid', 'cancelled'))",
    "CHECK (occurrence_date GLOB "
        "'[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]')",
    "CHECK (created_at GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*Z')",
  ];
}
