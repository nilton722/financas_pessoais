import 'package:drift/drift.dart';

import 'accounts.dart';
import 'categories.dart';
import 'transactions.dart';

const plannedItemKinds = ['income', 'expense'];
const plannedItemStatuses = ['planned', 'partially_paid', 'paid', 'cancelled'];

/// Compromissos futuros de rendimento ou despesa. Nunca entram no cálculo de
/// saldo: só o movimento real criado ao pagar afeta o caixa.
class PlannedItems extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  TextColumn get accountId => text().nullable().references(Accounts, #id)();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  IntColumn get amount => integer()();
  TextColumn get dueDate => text()();
  TextColumn get description => text().withLength(min: 1)();
  TextColumn get status => text().withDefault(const Constant('planned'))();

  /// Movimento que liquidou o compromisso (preenchido quando fica pago).
  TextColumn get transactionId =>
      text().nullable().references(Transactions, #id)();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    "CHECK (kind IN ('income', 'expense'))",
    'CHECK (amount > 0)',
    "CHECK (status IN ('planned', 'partially_paid', 'paid', 'cancelled'))",
    "CHECK (due_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]')",
    "CHECK (created_at GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*Z')",
    "CHECK (updated_at GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*Z')",
  ];
}

/// Alocação explícita de um movimento real a um compromisso. Permite
/// pagamentos parciais sem dupla contagem: um movimento liquida no máximo um
/// compromisso (`UNIQUE(transaction_id)`) e o total alocado nunca pode
/// exceder o valor do compromisso (validado no repositório).
class PlannedItemPayments extends Table {
  TextColumn get id => text()();
  TextColumn get plannedItemId => text().references(PlannedItems, #id)();
  TextColumn get transactionId => text().references(Transactions, #id)();
  IntColumn get amount => integer()();
  TextColumn get paymentDate => text()();
  TextColumn get createdAt => text()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (amount > 0)',
    'UNIQUE (transaction_id)',
    "CHECK (payment_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]')",
    "CHECK (created_at GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*Z')",
  ];
}
