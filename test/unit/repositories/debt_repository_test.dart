import 'package:financas_pessoais/core/database/app_database.dart'
    hide Debt, DebtPayment;
import 'package:financas_pessoais/core/errors/app_failure.dart';
import 'package:financas_pessoais/core/formatters/date_formatter.dart';
import 'package:financas_pessoais/features/accounts/data/account_repository.dart';
import 'package:financas_pessoais/features/planning/data/debt_repository.dart';
import 'package:financas_pessoais/features/planning/domain/debt.dart';
import 'package:financas_pessoais/features/transactions/data/transaction_repository.dart';
import 'package:financas_pessoais/features/transactions/domain/movement.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/database_fixtures.dart';
import '../../support/domain_fixtures.dart';

void main() {
  late AppDatabase db;
  late TransactionRepository transactions;
  late DebtRepository debts;

  setUp(() {
    db = openMemoryDatabase();
    transactions = TransactionRepository(db);
    debts = DebtRepository(db);
  });

  tearDown(() => db.close());

  DebtDraft debtDraft({
    DebtKind kind = DebtKind.payable,
    int amount = 30000,
    String description = 'Empréstimo',
  }) {
    return DebtDraft(
      kind: kind,
      description: description,
      originalAmount: amount,
      counterparty: 'Banco',
      dueDate: FinancialDate.today().add(const Duration(days: 30)),
    );
  }

  DebtPaymentDraft paymentDraft({
    required String accountId,
    required int amount,
    DebtKind kind = DebtKind.payable,
  }) {
    return DebtPaymentDraft(
      amount: amount,
      date: FinancialDate.today(),
      accountId: accountId,
      categoryId: kind == DebtKind.payable
          ? seededFoodCategoryId
          : seededSalaryCategoryId,
      description: 'Prestação',
    );
  }

  Future<int> balanceOf(String accountId) async {
    final entries = await AccountRepository(db)
        .readBalances(until: FinancialDate.today());
    return entries
        .singleWhere((entry) => entry.account.id == accountId)
        .balance;
  }

  test('dívida não altera caixa; pagamento cria um único movimento', () async {
    final wallet = await createTestAccount(db, openingBalance: 50000);
    final debtId = await debts.create(debtDraft());
    expect(await balanceOf(wallet), 50000);

    await debts.pay(debtId, paymentDraft(accountId: wallet, amount: 10000));
    var debt = await debts.findById(debtId);
    expect(debt!.remaining, 20000);
    expect(debt.effectiveStatus, DebtStatus.open);
    expect(debt.paidTotal, 10000);
    expect(await balanceOf(wallet), 40000);

    await debts.pay(debtId, paymentDraft(accountId: wallet, amount: 20000));
    debt = await debts.findById(debtId);
    expect(debt!.remaining, 0);
    expect(debt.effectiveStatus, DebtStatus.paid);
    expect(await balanceOf(wallet), 20000);
    expect(
      (await transactions.watchMovements(const MovementFilter()).first),
      hasLength(2),
    );
    expect(await debts.readPayments(debtId), hasLength(2));
  });

  test('pagamento não pode exceder o valor em falta', () async {
    final wallet = await createTestAccount(db, openingBalance: 50000);
    final debtId = await debts.create(debtDraft(amount: 5000));

    await expectLater(
      debts.pay(debtId, paymentDraft(accountId: wallet, amount: 6000)),
      throwsA(isA<AppFailure>()),
    );
    expect(await balanceOf(wallet), 50000);
    expect(
      await transactions.watchMovements(const MovementFilter()).first,
      isEmpty,
    );
  });

  test('dívida a receber liquida-se com um rendimento', () async {
    final wallet = await createTestAccount(db, openingBalance: 0);
    final debtId = await debts.create(
      debtDraft(kind: DebtKind.receivable, amount: 8000, description: 'Venda'),
    );

    await debts.pay(
      debtId,
      paymentDraft(accountId: wallet, amount: 8000, kind: DebtKind.receivable),
    );

    expect(await balanceOf(wallet), 8000);
    final debt = await debts.findById(debtId);
    expect(debt!.effectiveStatus, DebtStatus.paid);
    final movement =
        (await transactions.watchMovements(const MovementFilter()).first)
            .single;
    expect(movement.movement.kind, MovementKind.income);
  });

  test('cancelar impede novos pagamentos sem mexer no caixa', () async {
    final wallet = await createTestAccount(db, openingBalance: 50000);
    final debtId = await debts.create(debtDraft());
    await debts.cancel(debtId);

    expect(
      (await debts.findById(debtId))!.effectiveStatus,
      DebtStatus.cancelled,
    );
    await expectLater(
      debts.pay(debtId, paymentDraft(accountId: wallet, amount: 1000)),
      throwsA(isA<AppFailure>()),
    );
    expect(await balanceOf(wallet), 50000);
  });

  test('pendente deriva de pagamentos reais, não do estado guardado', () async {
    final wallet = await createTestAccount(db, openingBalance: 50000);
    final debtId = await debts.create(debtDraft(amount: 5000));
    final transactionId = await debts.pay(
      debtId,
      paymentDraft(accountId: wallet, amount: 5000),
    );
    expect((await debts.findById(debtId))!.effectiveStatus, DebtStatus.paid);

    await transactions.softDelete(transactionId);

    final debt = await debts.findById(debtId);
    expect(debt!.paidTotal, 0);
    expect(debt.remaining, 5000);
    expect(debt.effectiveStatus, DebtStatus.open);
    expect(await balanceOf(wallet), 50000);
  });

  test('edição não pode reduzir abaixo do total pago', () async {
    final wallet = await createTestAccount(db, openingBalance: 50000);
    final debtId = await debts.create(debtDraft(amount: 10000));
    await debts.pay(debtId, paymentDraft(accountId: wallet, amount: 4000));

    await expectLater(
      debts.update(
        debtId,
        DebtDraft(
          kind: DebtKind.payable,
          description: 'Empréstimo',
          originalAmount: 3000,
        ),
      ),
      throwsA(isA<AppFailure>()),
    );
  });
}
