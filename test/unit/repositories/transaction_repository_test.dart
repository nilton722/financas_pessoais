import 'package:financas_pessoais/core/database/app_database.dart';
import 'package:financas_pessoais/core/errors/app_failure.dart';
import 'package:financas_pessoais/core/formatters/date_formatter.dart';
import 'package:financas_pessoais/features/accounts/data/account_repository.dart';
import 'package:financas_pessoais/features/accounts/domain/account.dart';
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

  MovementDraft incomeDraft({
    required String accountId,
    int amount = 1000,
    DateTime? date,
  }) {
    return MovementDraft(
      kind: MovementKind.income,
      amount: amount,
      date: date ?? FinancialDate.today(),
      accountId: accountId,
      categoryId: seededSalaryCategoryId,
      description: 'Rendimento',
    );
  }

  MovementDraft expenseDraft({
    required String accountId,
    int amount = 500,
    DateTime? date,
  }) {
    return MovementDraft(
      kind: MovementKind.expense,
      amount: amount,
      date: date ?? FinancialDate.today(),
      accountId: accountId,
      categoryId: seededFoodCategoryId,
      description: 'Despesa',
    );
  }

  Future<int> balanceOf(String accountId, {DateTime? until}) async {
    final entries = await accounts.readBalances(
      until: until ?? FinancialDate.today(),
    );
    return entries
        .singleWhere((entry) => entry.account.id == accountId)
        .balance;
  }

  test('lista movimentos com nomes de conta e categoria', () async {
    final accountId = await createTestAccount(db, name: 'Carteira');
    await transactions.createMovement(incomeDraft(accountId: accountId));

    final items = await transactions
        .watchMovements(const MovementFilter())
        .first;
    final item = items.single;
    expect(item.movement.kind, MovementKind.income);
    expect(item.movement.amount, 1000);
    expect(item.accountName, 'Carteira');
    expect(item.categoryName, 'Salário');
  });

  test('transferência falhada não deixa movimentos parciais', () async {
    final wallet = await createTestAccount(db, openingBalance: 5000);

    await expectLater(
      transactions.createTransfer(
        TransferDraft(
          sourceAccountId: wallet,
          destinationAccountId: 'conta-inexistente',
          amount: 1000,
          date: FinancialDate.today(),
          description: 'Falha',
        ),
      ),
      throwsA(isA<AppFailure>()),
    );

    expect(
      await transactions.watchMovements(const MovementFilter()).first,
      isEmpty,
    );
    expect(await balanceOf(wallet), 5000);
  });

  test(
    'rejeita transferência entre contas do mesmo titular com moedas diferentes',
    () async {
      final wallet = await createTestAccount(db, name: 'Carteira');
      final foreign = await accounts.create(
        AccountDraft(
          name: 'Conta EUR',
          type: AccountType.bank,
          openingBalance: 0,
          openingDate: FinancialDate.today(),
          currencyCode: 'EUR',
        ),
      );

      await expectLater(
        transactions.createTransfer(
          TransferDraft(
            sourceAccountId: wallet,
            destinationAccountId: foreign,
            amount: 1000,
            date: FinancialDate.today(),
            description: 'Conversão',
          ),
        ),
        throwsA(isA<AppFailure>()),
      );
    },
  );

  test('rejeita categoria de tipo incompatível', () async {
    final accountId = await createTestAccount(db);

    await expectLater(
      transactions.createMovement(
        MovementDraft(
          kind: MovementKind.expense,
          amount: 1000,
          date: FinancialDate.today(),
          accountId: accountId,
          categoryId: seededSalaryCategoryId,
          description: 'Categoria errada',
        ),
      ),
      throwsA(isA<AppFailure>()),
    );
  });

  test('rejeita conta arquivada em novos movimentos', () async {
    final accountId = await createTestAccount(db);
    await accounts.setArchived(accountId, archived: true);

    await expectLater(
      transactions.createMovement(incomeDraft(accountId: accountId)),
      throwsA(isA<AppFailure>()),
    );
  });

  test('filtra por tipo, conta, categoria e intervalo de datas', () async {
    final wallet = await createTestAccount(db, name: 'Carteira');
    final savings = await createTestAccount(db, name: 'Poupança');

    await transactions.createMovement(incomeDraft(accountId: wallet));
    await transactions.createMovement(expenseDraft(accountId: wallet));
    await transactions.createTransfer(
      TransferDraft(
        sourceAccountId: wallet,
        destinationAccountId: savings,
        amount: 2000,
        date: FinancialDate.today(),
        description: 'Reserva',
      ),
    );
    await transactions.createMovement(
      incomeDraft(accountId: savings, amount: 700, date: daysAgo(3)),
    );

    Future<int> count(MovementFilter filter) async =>
        (await transactions.watchMovements(filter).first).length;

    expect(await count(const MovementFilter()), 4);
    expect(await count(const MovementFilter(kind: MovementKind.income)), 2);
    expect(await count(MovementFilter(accountId: savings)), 2);
    expect(
      await count(const MovementFilter(categoryId: seededFoodCategoryId)),
      1,
    );
    expect(
      await count(MovementFilter(from: daysAgo(1), to: FinancialDate.today())),
      3,
    );

    final ordered = await transactions
        .watchMovements(const MovementFilter())
        .first;
    expect(ordered.last.movement.date, daysAgo(3));
  });

  test('eliminação lógica remove da lista e reverte o saldo', () async {
    final accountId = await createTestAccount(db, openingBalance: 5000);
    final movementId = await transactions.createMovement(
      incomeDraft(accountId: accountId),
    );

    expect(await balanceOf(accountId), 6000);

    await transactions.softDelete(movementId);

    expect(
      await transactions.watchMovements(const MovementFilter()).first,
      isEmpty,
    );
    expect(await balanceOf(accountId), 5000);
    expect(await transactions.findById(movementId), isNotNull);
  });

  test('edição retroativa recalcula o saldo', () async {
    final accountId = await createTestAccount(db, openingBalance: 5000);
    final movementId = await transactions.createMovement(
      incomeDraft(accountId: accountId, amount: 1000, date: daysAgo(10)),
    );

    expect(await balanceOf(accountId), 6000);

    await transactions.updateMovement(
      movementId,
      incomeDraft(accountId: accountId, amount: 2500, date: daysAgo(10)),
    );

    expect(await balanceOf(accountId), 7500);
  });

  test('eliminar transferência reverte ambos os saldos', () async {
    final wallet = await createTestAccount(
      db,
      name: 'Carteira',
      openingBalance: 9000,
    );
    final savings = await createTestAccount(db, name: 'Poupança');

    final transferId = await transactions.createTransfer(
      TransferDraft(
        sourceAccountId: wallet,
        destinationAccountId: savings,
        amount: 3000,
        date: FinancialDate.today(),
        description: 'Reserva',
      ),
    );

    expect(await balanceOf(wallet), 6000);
    expect(await balanceOf(savings), 3000);

    await transactions.softDelete(transferId);

    expect(await balanceOf(wallet), 9000);
    expect(await balanceOf(savings), 0);
  });

  test(
    'movimento de transferência não pode ser editado como rendimento',
    () async {
      final wallet = await createTestAccount(db, name: 'Carteira');
      final savings = await createTestAccount(db, name: 'Poupança');
      final transferId = await transactions.createTransfer(
        TransferDraft(
          sourceAccountId: wallet,
          destinationAccountId: savings,
          amount: 1000,
          date: FinancialDate.today(),
          description: 'Reserva',
        ),
      );

      await expectLater(
        transactions.updateMovement(transferId, incomeDraft(accountId: wallet)),
        throwsA(isA<AppFailure>()),
      );
    },
  );
}
