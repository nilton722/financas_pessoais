import 'package:financas_pessoais/core/database/app_database.dart'
    hide Debt, DebtPayment, PlannedItem;
import 'package:financas_pessoais/core/errors/app_failure.dart';
import 'package:financas_pessoais/core/formatters/date_formatter.dart';
import 'package:financas_pessoais/features/accounts/data/account_repository.dart';
import 'package:financas_pessoais/features/planning/data/debt_repository.dart';
import 'package:financas_pessoais/features/planning/data/planning_repository.dart';
import 'package:financas_pessoais/features/planning/domain/debt.dart';
import 'package:financas_pessoais/features/planning/domain/planned_item.dart';
import 'package:financas_pessoais/features/planning/domain/recurrence.dart';
import 'package:financas_pessoais/features/transactions/data/transaction_repository.dart';
import 'package:financas_pessoais/features/transactions/domain/movement.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/database_fixtures.dart';
import '../../support/domain_fixtures.dart';

void main() {
  late AppDatabase db;
  late AccountRepository accounts;
  late TransactionRepository transactions;
  late PlanningRepository planning;
  late DebtRepository debts;

  setUp(() {
    db = openMemoryDatabase();
    accounts = AccountRepository(db);
    transactions = TransactionRepository(db);
    planning = PlanningRepository(db);
    debts = DebtRepository(db);
  });

  tearDown(() => db.close());

  Future<int> balanceOf(String accountId) async {
    final entries = await accounts.readBalances(until: FinancialDate.today());
    return entries
        .singleWhere((entry) => entry.account.id == accountId)
        .balance;
  }

  MovementDraft movementDraft({
    required String accountId,
    required int amount,
    MovementKind kind = MovementKind.expense,
  }) {
    return MovementDraft(
      kind: kind,
      amount: amount,
      date: FinancialDate.today(),
      accountId: accountId,
      categoryId: kind == MovementKind.expense
          ? seededFoodCategoryId
          : seededSalaryCategoryId,
      description: 'Pagamento',
    );
  }

  test('editar pagamento dentro do limite acompanha a alocação', () async {
    final wallet = await createTestAccount(db, openingBalance: 10000);
    final itemId = await planning.createItem(
      PlannedItemDraft(
        kind: PlannedItemKind.expense,
        amount: 3000,
        dueDate: FinancialDate.today(),
        description: 'Renda',
        accountId: wallet,
        categoryId: seededFoodCategoryId,
      ),
    );
    final transactionId = await planning.payItem(
      itemId,
      PaymentDraft(
        amount: 1000,
        date: FinancialDate.today(),
        accountId: wallet,
        categoryId: seededFoodCategoryId,
      ),
    );

    await transactions.updateMovement(
      transactionId,
      movementDraft(accountId: wallet, amount: 2500),
    );

    var item = await planning.findItem(itemId);
    expect(item!.paidTotal, 2500);
    expect(item.remaining, 500);
    expect(item.effectiveStatus, PlannedItemStatus.partiallyPaid);
    expect(await balanceOf(wallet), 7500);
    expect((await planning.readPayments(itemId)).single.amount, 2500);

    await expectLater(
      transactions.updateMovement(
        transactionId,
        movementDraft(accountId: wallet, amount: 4000),
      ),
      throwsA(isA<AppFailure>()),
    );
    item = await planning.findItem(itemId);
    expect(item!.paidTotal, 2500);
    expect(await balanceOf(wallet), 7500);
  });

  test('editar pagamento até ao valor fecha o compromisso', () async {
    final wallet = await createTestAccount(db, openingBalance: 10000);
    final itemId = await planning.createItem(
      PlannedItemDraft(
        kind: PlannedItemKind.expense,
        amount: 2000,
        dueDate: FinancialDate.today(),
        description: 'Renda',
        accountId: wallet,
        categoryId: seededFoodCategoryId,
      ),
    );
    final transactionId = await planning.payItem(
      itemId,
      PaymentDraft(
        amount: 500,
        date: FinancialDate.today(),
        accountId: wallet,
        categoryId: seededFoodCategoryId,
      ),
    );

    await transactions.updateMovement(
      transactionId,
      movementDraft(accountId: wallet, amount: 2000),
    );

    final item = await planning.findItem(itemId);
    expect(item!.effectiveStatus, PlannedItemStatus.paid);
    expect(item.transactionId, transactionId);
    expect(await balanceOf(wallet), 8000);
  });

  test('eliminar pagamento liberta o compromisso e o saldo', () async {
    final wallet = await createTestAccount(db, openingBalance: 10000);
    final itemId = await planning.createItem(
      PlannedItemDraft(
        kind: PlannedItemKind.expense,
        amount: 3000,
        dueDate: FinancialDate.today(),
        description: 'Renda',
        accountId: wallet,
        categoryId: seededFoodCategoryId,
      ),
    );
    final transactionId = await planning.payItem(
      itemId,
      PaymentDraft(
        amount: 3000,
        date: FinancialDate.today(),
        accountId: wallet,
        categoryId: seededFoodCategoryId,
      ),
    );
    expect(await balanceOf(wallet), 7000);

    await transactions.softDelete(transactionId);

    final item = await planning.findItem(itemId);
    expect(item!.paidTotal, 0);
    expect(item.effectiveStatus, PlannedItemStatus.planned);
    expect(item.transactionId, isNull);
    expect(await planning.readPayments(itemId), isEmpty);
    expect(await balanceOf(wallet), 10000);
  });

  test(
    'eliminar pagamento repõe a ocorrência recorrente como planeada',
    () async {
      final wallet = await createTestAccount(db, openingBalance: 10000);
      await planning.createRule(
        RecurringRuleDraft(
          kind: PlannedItemKind.expense,
          amount: 1000,
          frequency: RecurrenceFrequency.monthly,
          startDate: FinancialDate.today(),
          description: 'Internet',
          accountId: wallet,
          categoryId: seededFoodCategoryId,
        ),
      );
      await planning.syncRecurrences(horizon: FinancialDate.today());
      final itemId = (await planning.readItems()).single.id;
      final transactionId = await planning.payItem(
        itemId,
        PaymentDraft(
          amount: 1000,
          date: FinancialDate.today(),
          accountId: wallet,
          categoryId: seededFoodCategoryId,
        ),
      );
      expect(
        (await db.select(db.recurringOccurrences).get()).single.status,
        'paid',
      );

      await transactions.softDelete(transactionId);

      final occurrence =
          (await db.select(db.recurringOccurrences).get()).single;
      expect(occurrence.status, 'planned');
      expect(occurrence.transactionId, isNull);
      expect(
        (await planning.findItem(itemId))!.effectiveStatus,
        PlannedItemStatus.planned,
      );
    },
  );

  test('editar pagamento de dívida respeita o valor original', () async {
    final wallet = await createTestAccount(db, openingBalance: 10000);
    final debtId = await debts.create(
      const DebtDraft(
        kind: DebtKind.payable,
        description: 'Empréstimo',
        originalAmount: 5000,
      ),
    );
    final transactionId = await debts.pay(
      debtId,
      DebtPaymentDraft(
        amount: 2000,
        date: FinancialDate.today(),
        accountId: wallet,
        categoryId: seededFoodCategoryId,
      ),
    );

    await transactions.updateMovement(
      transactionId,
      movementDraft(accountId: wallet, amount: 4000),
    );
    var debt = await debts.findById(debtId);
    expect(debt!.paidTotal, 4000);
    expect(debt.remaining, 1000);
    expect(await balanceOf(wallet), 6000);

    await expectLater(
      transactions.updateMovement(
        transactionId,
        movementDraft(accountId: wallet, amount: 6000),
      ),
      throwsA(isA<AppFailure>()),
    );
    debt = await debts.findById(debtId);
    expect(debt!.paidTotal, 4000);
    expect(await balanceOf(wallet), 6000);
  });

  test('eliminar pagamento repõe o pendente da dívida', () async {
    final wallet = await createTestAccount(db, openingBalance: 10000);
    final debtId = await debts.create(
      const DebtDraft(
        kind: DebtKind.payable,
        description: 'Empréstimo',
        originalAmount: 5000,
      ),
    );
    final transactionId = await debts.pay(
      debtId,
      DebtPaymentDraft(
        amount: 5000,
        date: FinancialDate.today(),
        accountId: wallet,
        categoryId: seededFoodCategoryId,
      ),
    );
    expect((await debts.findById(debtId))!.effectiveStatus, DebtStatus.paid);

    await transactions.softDelete(transactionId);

    final debt = await debts.findById(debtId);
    expect(debt!.paidTotal, 0);
    expect(debt.remaining, 5000);
    expect(debt.effectiveStatus, DebtStatus.open);
    expect(await debts.readPayments(debtId), isEmpty);
    expect(await balanceOf(wallet), 10000);
  });
}
