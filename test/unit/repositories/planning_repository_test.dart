import 'package:financas_pessoais/core/database/app_database.dart';
import 'package:financas_pessoais/core/errors/app_failure.dart';
import 'package:financas_pessoais/core/formatters/date_formatter.dart';
import 'package:financas_pessoais/features/accounts/data/account_repository.dart';
import 'package:financas_pessoais/features/planning/data/planning_repository.dart';
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

  setUp(() {
    db = openMemoryDatabase();
    accounts = AccountRepository(db);
    transactions = TransactionRepository(db);
    planning = PlanningRepository(db);
  });

  tearDown(() => db.close());

  PlannedItemDraft expenseDraft({
    required String accountId,
    int amount = 3000,
    String description = 'Renda da casa',
    int dueInDays = 10,
  }) {
    return PlannedItemDraft(
      kind: PlannedItemKind.expense,
      amount: amount,
      dueDate: FinancialDate.today().add(Duration(days: dueInDays)),
      description: description,
      accountId: accountId,
      categoryId: seededFoodCategoryId,
    );
  }

  PaymentDraft paymentDraft({
    required String accountId,
    required int amount,
    String? categoryId = seededFoodCategoryId,
  }) {
    return PaymentDraft(
      amount: amount,
      date: FinancialDate.today(),
      accountId: accountId,
      categoryId: categoryId,
      description: 'Pagamento',
    );
  }

  Future<int> balanceOf(String accountId) async {
    final entries = await accounts.readBalances(until: FinancialDate.today());
    return entries
        .singleWhere((entry) => entry.account.id == accountId)
        .balance;
  }

  Future<int> movementCount() async =>
      (await transactions.watchMovements(const MovementFilter()).first).length;

  test('compromisso futuro não altera o saldo real', () async {
    final wallet = await createTestAccount(db, openingBalance: 10000);

    await planning.createItem(expenseDraft(accountId: wallet));

    expect(await balanceOf(wallet), 10000);
    expect(await movementCount(), 0);
    final items = await planning.readItems();
    expect(items.single.remaining, 3000);
    expect(items.single.effectiveStatus, PlannedItemStatus.planned);
  });

  test('pagar cria um único movimento e não duplica caixa', () async {
    final wallet = await createTestAccount(db, openingBalance: 10000);
    final itemId = await planning.createItem(expenseDraft(accountId: wallet));

    final transactionId = await planning.payItem(
      itemId,
      paymentDraft(accountId: wallet, amount: 3000),
    );

    expect(await balanceOf(wallet), 7000);
    expect(await movementCount(), 1);
    final item = await planning.findItem(itemId);
    expect(item!.effectiveStatus, PlannedItemStatus.paid);
    expect(item.paidTotal, 3000);
    expect(item.remaining, 0);
    expect(item.transactionId, transactionId);
    expect(await planning.readPayments(itemId), hasLength(1));
  });

  test('pagamentos parciais somam e não excedem o compromisso', () async {
    final wallet = await createTestAccount(db, openingBalance: 10000);
    final itemId = await planning.createItem(expenseDraft(accountId: wallet));

    await planning.payItem(
      itemId,
      paymentDraft(accountId: wallet, amount: 1000),
    );
    var item = await planning.findItem(itemId);
    expect(item!.effectiveStatus, PlannedItemStatus.partiallyPaid);
    expect(item.remaining, 2000);
    expect(await balanceOf(wallet), 9000);

    await expectLater(
      planning.payItem(itemId, paymentDraft(accountId: wallet, amount: 2500)),
      throwsA(isA<AppFailure>()),
    );
    expect(await balanceOf(wallet), 9000);
    expect(await movementCount(), 1);

    await planning.payItem(
      itemId,
      paymentDraft(accountId: wallet, amount: 2000),
    );
    item = await planning.findItem(itemId);
    expect(item!.effectiveStatus, PlannedItemStatus.paid);
    expect(await balanceOf(wallet), 7000);
    expect(await movementCount(), 2);
    expect(await planning.readPayments(itemId), hasLength(2));
  });

  test('cancelar retira da previsão sem tocar nos movimentos', () async {
    final wallet = await createTestAccount(db, openingBalance: 10000);
    final itemId = await planning.createItem(expenseDraft(accountId: wallet));
    await planning.payItem(
      itemId,
      paymentDraft(accountId: wallet, amount: 1000),
    );

    await planning.cancelItem(itemId);

    expect(await planning.readItems(pendingOnly: true), isEmpty);
    final item = await planning.findItem(itemId);
    expect(item!.effectiveStatus, PlannedItemStatus.cancelled);
    expect(await balanceOf(wallet), 9000);
    await expectLater(
      planning.payItem(itemId, paymentDraft(accountId: wallet, amount: 100)),
      throwsA(isA<AppFailure>()),
    );
  });

  test('compromisso liquidado não pode ser cancelado nem editado', () async {
    final wallet = await createTestAccount(db, openingBalance: 10000);
    final itemId = await planning.createItem(
      expenseDraft(accountId: wallet, amount: 500),
    );
    await planning.payItem(
      itemId,
      paymentDraft(accountId: wallet, amount: 500),
    );

    await expectLater(planning.cancelItem(itemId), throwsA(isA<AppFailure>()));
    await expectLater(
      planning.updateItem(itemId, expenseDraft(accountId: wallet)),
      throwsA(isA<AppFailure>()),
    );
  });

  test('edição não pode reduzir abaixo do total já pago', () async {
    final wallet = await createTestAccount(db, openingBalance: 10000);
    final itemId = await planning.createItem(expenseDraft(accountId: wallet));
    await planning.payItem(
      itemId,
      paymentDraft(accountId: wallet, amount: 2000),
    );

    await expectLater(
      planning.updateItem(
        itemId,
        expenseDraft(accountId: wallet, amount: 1500),
      ),
      throwsA(isA<AppFailure>()),
    );
  });

  test('recorrência gera ocorrências idempotentes', () async {
    final wallet = await createTestAccount(db, openingBalance: 10000);
    final today = FinancialDate.today();
    final ruleId = await planning.createRule(
      RecurringRuleDraft(
        kind: PlannedItemKind.expense,
        amount: 2500,
        frequency: RecurrenceFrequency.monthly,
        startDate: today,
        description: 'Renda',
        accountId: wallet,
        categoryId: seededFoodCategoryId,
      ),
    );

    final horizon = DateTime(today.year, today.month + 3, today.day);
    expect(await planning.syncRecurrences(horizon: horizon), 4);
    expect(await planning.readItems(), hasLength(4));
    expect(await balanceOf(wallet), 10000);
    expect(await movementCount(), 0);

    expect(await planning.syncRecurrences(horizon: horizon), 0);
    expect(await planning.readItems(), hasLength(4));

    final occurrences = await db.select(db.recurringOccurrences).get();
    expect(occurrences, hasLength(4));
    expect(
      occurrences.every((occurrence) => occurrence.ruleId == ruleId),
      true,
    );
  });

  test('recorrência respeita a data de fim', () async {
    final wallet = await createTestAccount(db);
    final today = FinancialDate.today();
    await planning.createRule(
      RecurringRuleDraft(
        kind: PlannedItemKind.expense,
        amount: 1000,
        frequency: RecurrenceFrequency.monthly,
        startDate: today,
        endDate: today,
        description: 'Única',
        accountId: wallet,
        categoryId: seededFoodCategoryId,
      ),
    );

    expect(
      await planning.syncRecurrences(
        horizon: today.add(const Duration(days: 90)),
      ),
      1,
    );
    final rule = (await planning.readRules()).single;
    expect(rule.hasEnded, isTrue);
  });

  test('pagar ocorrência marca-a como paga sem a duplicar', () async {
    final wallet = await createTestAccount(db, openingBalance: 10000);
    final today = FinancialDate.today();
    await planning.createRule(
      RecurringRuleDraft(
        kind: PlannedItemKind.expense,
        amount: 2000,
        frequency: RecurrenceFrequency.monthly,
        startDate: today,
        description: 'Internet',
        accountId: wallet,
        categoryId: seededFoodCategoryId,
      ),
    );
    await planning.syncRecurrences(horizon: today);
    final item = (await planning.readItems()).single;

    await planning.payItem(
      item.id,
      paymentDraft(accountId: wallet, amount: 2000),
    );

    expect(await balanceOf(wallet), 8000);
    expect(await movementCount(), 1);
    final occurrence = (await db.select(db.recurringOccurrences).get()).single;
    expect(occurrence.status, 'paid');
    expect(occurrence.transactionId, isNotNull);

    // A sincronização seguinte não volta a criar a mesma ocorrência.
    await planning.syncRecurrences(horizon: today.add(const Duration(days: 5)));
    expect(await planning.readItems(), hasLength(1));
    expect(await balanceOf(wallet), 8000);
  });

  test('não altera frequência depois de gerar ocorrências', () async {
    final wallet = await createTestAccount(db);
    final today = FinancialDate.today();
    await planning.createRule(
      RecurringRuleDraft(
        kind: PlannedItemKind.expense,
        amount: 1000,
        frequency: RecurrenceFrequency.monthly,
        startDate: today,
        description: 'Renda',
        accountId: wallet,
        categoryId: seededFoodCategoryId,
      ),
    );
    await planning.syncRecurrences(horizon: today);

    await expectLater(
      planning.updateRule(
        (await planning.readRules()).single.id,
        RecurringRuleDraft(
          kind: PlannedItemKind.expense,
          amount: 1000,
          frequency: RecurrenceFrequency.weekly,
          startDate: today,
          description: 'Renda',
          accountId: wallet,
          categoryId: seededFoodCategoryId,
        ),
      ),
      throwsA(isA<AppFailure>()),
    );
  });

  test('regra inativa não gera ocorrências', () async {
    final wallet = await createTestAccount(db);
    final today = FinancialDate.today();
    final ruleId = await planning.createRule(
      RecurringRuleDraft(
        kind: PlannedItemKind.expense,
        amount: 1000,
        frequency: RecurrenceFrequency.monthly,
        startDate: today,
        description: 'Renda',
        accountId: wallet,
        categoryId: seededFoodCategoryId,
      ),
    );
    await planning.setRuleActive(ruleId, active: false);

    expect(
      await planning.syncRecurrences(
        horizon: today.add(const Duration(days: 30)),
      ),
      0,
    );
    expect(await planning.readItems(), isEmpty);
  });
}
