import 'package:drift/drift.dart';

import 'accounts.dart';

/// Meta de poupança. Não é uma despesa: o progresso é lido do saldo da conta
/// associada (movimentos reais), nunca de um valor artificial.
class SavingsGoals extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1)();
  IntColumn get targetAmount => integer()();
  TextColumn get targetDate => text().nullable()();
  TextColumn get linkedAccountId =>
      text().nullable().references(Accounts, #id)();
  TextColumn get notes => text().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (target_amount > 0)',
    "CHECK (target_date IS NULL OR "
        "target_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]')",
    "CHECK (created_at GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*Z')",
    "CHECK (updated_at GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*Z')",
  ];
}
