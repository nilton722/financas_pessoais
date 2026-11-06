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

  test('aceita o montante máximo e mantém aritmética inteira', () async {
    final wallet = await createTestAccount(db, openingBalance: 1);
    const limit = 999999999999;

    await transactions.createMovement(
      incomeDraft(accountId: wallet, amount: limit),
    );

    final stored = (await transactions.readMovements(const MovementFilter()))
        .single;
    expect(stored.movement.amount, limit);
    expect(await balanceOf(wallet), limit + 1);
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

  test('pesquisa descrição, notas, categoria, conta e destino', () async {
    final wallet = await createTestAccount(db, name: 'Carteira');
    final savings = await createTestAccount(db, name: 'Poupança');
    await transactions.createMovement(
      MovementDraft(
        kind: MovementKind.income,
        amount: 2500,
        date: FinancialDate.today(),
        accountId: wallet,
        categoryId: seededSalaryCategoryId,
        description: 'Salário de outubro',
        notes: 'Bónus trimestral',
      ),
    );
    await transactions.createMovement(
      MovementDraft(
        kind: MovementKind.expense,
        amount: 800,
        date: FinancialDate.today(),
        accountId: wallet,
        categoryId: seededFoodCategoryId,
        description: 'Mercado',
        notes: 'Feira semanal',
      ),
    );
    await transactions.createTransfer(
      TransferDraft(
        sourceAccountId: wallet,
        destinationAccountId: savings,
        amount: 500,
        date: FinancialDate.today(),
        description: 'Reserva de emergência',
      ),
    );

    Future<int> count(String query) async =>
        (await transactions.readMovements(MovementFilter(query: query))).length;

    expect(await count('salário'), 1);
    expect(await count('bónus'), 1);
    expect(await count('feira'), 1);
    expect(await count('alimenta'), 1);
    expect(await count('poupança'), 1);
    expect(await count('carteira'), 3);
    expect(await count('inexistente'), 0);
    expect(await count('   '), 3);
  });

  test('pesquisa trata % e _ como caracteres literais', () async {
    final wallet = await createTestAccount(db);
    await transactions.createMovement(
      MovementDraft(
        kind: MovementKind.expense,
        amount: 100,
        date: FinancialDate.today(),
        accountId: wallet,
        categoryId: seededFoodCategoryId,
        description: 'Desconto 50%',
        notes: 'Código A_B',
      ),
    );

    Future<int> count(String query) async =>
        (await transactions.readMovements(MovementFilter(query: query))).length;

    expect(await count('%'), 1);
    expect(await count('_'), 1);
    expect(await count('50%'), 1);
    expect(await count('A_B'), 1);
  });

  test('lixeira lista, restaura e elimina definitivamente', () async {
    final wallet = await createTestAccount(db, openingBalance: 5000);
    final movementId = await transactions.createMovement(
      incomeDraft(accountId: wallet),
    );
    expect(await balanceOf(wallet), 6000);

    await transactions.softDelete(movementId);

    expect(await transactions.readMovements(const MovementFilter()), isEmpty);
    final deleted = await transactions.watchDeletedMovements().first;
    expect(deleted.single.movement.id, movementId);
    expect(await balanceOf(wallet), 5000);

    await transactions.restore(movementId);

    expect(
      (await transactions.readMovements(const MovementFilter()))
          .single
          .movement
          .id,
      movementId,
    );
    expect(await transactions.watchDeletedMovements().first, isEmpty);
    expect(await balanceOf(wallet), 6000);

    await transactions.softDelete(movementId);
    await transactions.deletePermanently(movementId);

    expect(await transactions.watchDeletedMovements().first, isEmpty);
    expect(await transactions.findById(movementId), isNull);
    expect(await balanceOf(wallet), 5000);
  });

  test(
    'eliminação definitiva exige que o movimento esteja na lixeira',
    () async {
      final wallet = await createTestAccount(db);
      final movementId = await transactions.createMovement(
        incomeDraft(accountId: wallet),
      );

      await expectLater(
        transactions.deletePermanently(movementId),
        throwsA(isA<AppFailure>()),
      );
      expect(await transactions.findById(movementId), isNotNull);
    },
  );
}
