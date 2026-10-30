import 'package:financas_pessoais/core/database/app_database.dart';
import 'package:financas_pessoais/core/formatters/date_formatter.dart';
import 'package:financas_pessoais/features/accounts/data/account_repository.dart';
import 'package:financas_pessoais/features/accounts/domain/account.dart';
import 'package:financas_pessoais/features/accounts/domain/account_balance.dart';
import 'package:financas_pessoais/features/transactions/data/transaction_repository.dart';
import 'package:financas_pessoais/features/transactions/domain/movement.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/database_fixtures.dart';
import '../../support/domain_fixtures.dart';

void main() {
  late AppDatabase db;
  late AccountRepository accounts;
  late TransactionRepository transactions;

  setUp(() {
    db = openMemoryDatabase();
    accounts = AccountRepository(db);
    transactions = TransactionRepository(db);
  });

  tearDown(() => db.close());

  MovementDraft draft({
    required String accountId,
    required int amount,
    MovementKind kind = MovementKind.expense,
    String? categoryId,
    DateTime? date,
  }) {
    return MovementDraft(
      kind: kind,
      amount: amount,
      date: date ?? FinancialDate.today(),
      accountId: accountId,
      categoryId:
          categoryId ??
          (kind == MovementKind.income
              ? seededSalaryCategoryId
              : seededFoodCategoryId),
      description: 'Movimento de teste',
    );
  }

  Future<Map<String, int>> balances({
    DateTime? until,
    bool includeArchived = false,
  }) async {
    final entries = await accounts.readBalances(
      until: until ?? FinancialDate.today(),
      includeArchived: includeArchived,
    );
    return {for (final entry in entries) entry.account.id: entry.balance};
  }

  test('cria, lista por nome e atualiza contas', () async {
    final wallet = await createTestAccount(
      db,
      name: 'Carteira',
      openingBalance: 5000,
    );
    final bank = await createTestAccount(
      db,
      name: 'Banco',
      type: AccountType.bank,
      openingBalance: 10000,
    );

    final list = await accounts.watchAll().first;
    expect(list.map((account) => account.name), ['Banco', 'Carteira']);
    expect(list.last.type, AccountType.cash);
    expect(list.first.openingBalance, 10000);

    await accounts.update(
      wallet,
      AccountDraft(
        name: 'Carteira pessoal',
        type: AccountType.cash,
        openingBalance: 6500,
        openingDate: FinancialDate.today(),
      ),
    );

    final updated = await accounts.findById(wallet);
    expect(updated?.name, 'Carteira pessoal');
    expect(updated?.openingBalance, 6500);
    expect(await accounts.findById(bank), isNotNull);
  });

  test('arquivar esconde a conta por omissão e reativar repõe', () async {
    final wallet = await createTestAccount(db, name: 'Carteira');

    await accounts.setArchived(wallet, archived: true);
    expect(await accounts.watchAll().first, isEmpty);
    expect(
      (await accounts.watchAll(includeArchived: true).first).single.isArchived,
      isTrue,
    );

    await accounts.setArchived(wallet, archived: false);
    expect((await accounts.watchAll().first).single.isArchived, isFalse);
  });

  test('saldo = saldo inicial + rendimento − despesa', () async {
    final wallet = await createTestAccount(db, openingBalance: 5000);

    await transactions.createMovement(
      draft(accountId: wallet, amount: 3000, kind: MovementKind.income),
    );
    await transactions.createMovement(draft(accountId: wallet, amount: 1200));

    expect((await balances())[wallet], 6800);
  });

  test('saldo real pode ficar negativo sem perder o sinal', () async {
    final wallet = await createTestAccount(db, openingBalance: 1000);

    await transactions.createMovement(draft(accountId: wallet, amount: 3000));

    expect((await balances())[wallet], -2000);
    final entries = await accounts.readBalances(until: FinancialDate.today());
    expect(consolidatedBalance(entries), -2000);
  });

  test(
    'transferência debita origem, credita destino e não altera o consolidado',
    () async {
      final wallet = await createTestAccount(
        db,
        name: 'Carteira',
        openingBalance: 10000,
      );
      final savings = await createTestAccount(
        db,
        name: 'Poupança',
        type: AccountType.savings,
      );

      await transactions.createTransfer(
        TransferDraft(
          sourceAccountId: wallet,
          destinationAccountId: savings,
          amount: 4000,
          date: FinancialDate.today(),
          description: 'Reserva',
        ),
      );

      final result = await balances();
      expect(result[wallet], 6000);
      expect(result[savings], 4000);

      final entries = await accounts.readBalances(until: FinancialDate.today());
      expect(consolidatedBalance(entries), 10000);
    },
  );

  test('movimentos eliminados logicamente saem do saldo', () async {
    final wallet = await createTestAccount(db, openingBalance: 5000);
    final movementId = await transactions.createMovement(
      draft(accountId: wallet, amount: 3000, kind: MovementKind.income),
    );

    expect((await balances())[wallet], 8000);

    await transactions.softDelete(movementId);
    expect((await balances())[wallet], 5000);
  });

  test('a data de referência exclui movimentos posteriores', () async {
    final wallet = await createTestAccount(db, openingBalance: 5000);
    await transactions.createMovement(
      draft(accountId: wallet, amount: 1000, kind: MovementKind.income),
    );

    expect((await balances(until: daysAgo(1)))[wallet], 5000);
    expect((await balances(until: FinancialDate.today()))[wallet], 6000);
  });

  test('conta arquivada fica fora do saldo por omissão', () async {
    final wallet = await createTestAccount(
      db,
      name: 'Carteira',
      openingBalance: 5000,
    );
    final old = await createTestAccount(
      db,
      name: 'Antiga',
      openingBalance: 2000,
    );
    await accounts.setArchived(old, archived: true);

    final visible = await balances();
    expect(visible.keys, [wallet]);

    final all = await balances(includeArchived: true);
    expect(all[old], 2000);
  });
}
