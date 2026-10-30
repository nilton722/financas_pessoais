import 'package:drift/drift.dart';
import 'package:financas_pessoais/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/database_fixtures.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = openMemoryDatabase();
    await db.into(db.accounts).insert(accountCompanion(id: 'account-1'));
    await db.into(db.accounts).insert(accountCompanion(id: 'account-2'));
  });
  tearDown(() => db.close());

  Matcher failsWith(String constraint) => throwsA(
    predicate<Object>((error) => error.toString().contains(constraint)),
  );

  test('rejeita movimento com conta inexistente', () {
    expect(
      db
          .into(db.transactions)
          .insert(
            transactionCompanion(transactionFields(accountId: 'ausente')),
          ),
      failsWith('FOREIGN KEY'),
    );
  });

  test('rejeita categoria inexistente', () {
    final fields = transactionFields();
    expect(
      db
          .into(db.transactions)
          .insert(
            transactionCompanion(fields).copyWith(categoryId: const Value('x')),
          ),
      failsWith('FOREIGN KEY'),
    );
  });

  test('rejeita montante zero ou negativo', () {
    expect(
      db
          .into(db.transactions)
          .insert(transactionCompanion(transactionFields(amount: 0))),
      failsWith('CHECK'),
    );
    expect(
      db
          .into(db.transactions)
          .insert(transactionCompanion(transactionFields(amount: -100))),
      failsWith('CHECK'),
    );
  });

  test('transferência exige conta de destino', () {
    expect(
      db
          .into(db.transactions)
          .insert(transactionCompanion(transactionFields(kind: 'transfer'))),
      failsWith('CHECK'),
    );
  });

  test('transferência exige contas distintas', () {
    expect(
      db
          .into(db.transactions)
          .insert(
            transactionCompanion(
              transactionFields(
                kind: 'transfer',
                destinationAccountId: 'account-1',
              ),
            ),
          ),
      failsWith('CHECK'),
    );
  });

  test('rendimento e despesa não aceitam conta de destino', () {
    expect(
      db
          .into(db.transactions)
          .insert(
            transactionCompanion(
              transactionFields(destinationAccountId: 'account-2'),
            ),
          ),
      failsWith('CHECK'),
    );
  });

  test('rejeita data financeira fora de YYYY-MM-DD', () {
    expect(
      db
          .into(db.transactions)
          .insert(
            transactionCompanion(
              transactionFields(transactionDate: '29/10/2026'),
            ),
          ),
      failsWith('CHECK'),
    );
  });

  test('rejeita tipo de movimento desconhecido', () {
    expect(
      db
          .into(db.transactions)
          .insert(transactionCompanion(transactionFields(kind: 'ajuste'))),
      failsWith('CHECK'),
    );
  });

  test('aceita transferência válida', () async {
    await db
        .into(db.transactions)
        .insert(
          transactionCompanion(
            transactionFields(
              kind: 'transfer',
              destinationAccountId: 'account-2',
            ),
          ),
        );
    final stored = await db.select(db.transactions).getSingle();
    expect(stored.amount, 1000);
    expect(stored.destinationAccountId, 'account-2');
  });
}
