import 'package:drift/drift.dart';

import 'transactions.dart';

const debtKinds = ['payable', 'receivable'];
const debtStatuses = ['open', 'paid', 'cancelled'];

/// Dívida a pagar ou a receber. O pendente nunca é guardado: resulta do valor
/// original menos os pagamentos reais não eliminados.
class Debts extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  TextColumn get counterparty => text().nullable()();
  TextColumn get description => text().withLength(min: 1)();
  IntColumn get originalAmount => integer()();
  TextColumn get dueDate => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('open'))();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    "CHECK (kind IN ('payable', 'receivable'))",
    'CHECK (original_amount > 0)',
    "CHECK (status IN ('open', 'paid', 'cancelled'))",
    "CHECK (due_date IS NULL OR "
        "due_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]')",
    "CHECK (created_at GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*Z')",
    "CHECK (updated_at GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*Z')",
  ];
}

/// Liquidação de dívida: cada pagamento é um movimento real e uma alocação
/// explícita. `UNIQUE(transaction_id)` impede contar o mesmo movimento em
/// duas dívidas.
class DebtPayments extends Table {
  TextColumn get id => text()();
  TextColumn get debtId => text().references(Debts, #id)();
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
