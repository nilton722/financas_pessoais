import 'package:drift/drift.dart';

import 'accounts.dart';
import 'categories.dart';

const transactionKinds = ['income', 'expense', 'transfer'];

/// Movimentos realizados. `deleted_at` implementa eliminação lógica:
/// registos eliminados ficam fora de saldos, orçamentos e relatórios.
class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  @ReferenceName('sourceTransactions')
  TextColumn get accountId => text().references(Accounts, #id)();
  @ReferenceName('destinationTransactions')
  TextColumn get destinationAccountId =>
      text().nullable().references(Accounts, #id)();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  IntColumn get amount => integer()();
  TextColumn get transactionDate => text()();
  TextColumn get description => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  TextColumn get deletedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    "CHECK (kind IN ('income', 'expense', 'transfer'))",
    'CHECK (amount > 0)',
    'CHECK ((kind = \'transfer\' AND destination_account_id IS NOT NULL '
        'AND destination_account_id <> account_id) '
        "OR (kind <> 'transfer' AND destination_account_id IS NULL))",
    "CHECK (transaction_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]')",
    "CHECK (created_at GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*Z')",
    "CHECK (updated_at GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*Z')",
  ];
}
