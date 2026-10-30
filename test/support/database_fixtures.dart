import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:financas_pessoais/core/database/app_database.dart';

AppDatabase openMemoryDatabase() => AppDatabase(NativeDatabase.memory());

typedef TransactionFields = ({
  String id,
  String kind,
  String accountId,
  String? destinationAccountId,
  int amount,
  String transactionDate,
});

/// Campos obrigatórios com valores válidos; cada teste sobrescreve o que
/// pretende verificar.
TransactionFields transactionFields({
  String id = 'tx-1',
  String kind = 'expense',
  String accountId = 'account-1',
  String? destinationAccountId,
  int amount = 1000,
  String transactionDate = '2026-10-29',
}) => (
  id: id,
  kind: kind,
  accountId: accountId,
  destinationAccountId: destinationAccountId,
  amount: amount,
  transactionDate: transactionDate,
);

TransactionsCompanion transactionCompanion(TransactionFields fields) {
  const timestamp = '2026-10-29T10:00:00.000Z';
  return TransactionsCompanion.insert(
    id: fields.id,
    kind: fields.kind,
    accountId: fields.accountId,
    destinationAccountId: Value(fields.destinationAccountId),
    amount: fields.amount,
    transactionDate: fields.transactionDate,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

AccountsCompanion accountCompanion({String id = 'account-1'}) {
  return AccountsCompanion.insert(
    id: id,
    name: 'Conta $id',
    type: 'cash',
    openingDate: '2026-01-01',
    createdAt: '2026-01-01T00:00:00.000Z',
    updatedAt: '2026-01-01T00:00:00.000Z',
  );
}
