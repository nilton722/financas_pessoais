import 'package:drift/drift.dart';

const accountTypes = ['cash', 'bank', 'mobile_wallet', 'savings', 'other'];

/// Contas financeiras. `opening_balance` em inteiros FCFA/XOF.
class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1)();
  TextColumn get type => text()();
  TextColumn get currencyCode => text().withDefault(const Constant('XOF'))();
  IntColumn get openingBalance => integer().withDefault(const Constant(0))();
  TextColumn get openingDate => text()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    "CHECK (type IN ('cash', 'bank', 'mobile_wallet', 'savings', 'other'))",
    "CHECK (opening_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]')",
    "CHECK (created_at GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*Z')",
    "CHECK (updated_at GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*Z')",
  ];
}
