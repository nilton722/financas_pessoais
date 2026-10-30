import 'package:financas_pessoais/core/database/app_database.dart';
import 'package:financas_pessoais/core/formatters/date_formatter.dart';
import 'package:financas_pessoais/features/accounts/data/account_repository.dart';
import 'package:financas_pessoais/features/forecast/data/forecast_repository.dart';
import 'package:financas_pessoais/features/forecast/domain/forecast.dart';
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
  late TransactionRepository transactions;
  late PlanningRepository planning;
  late ForecastRepository forecast;

  setUp(() {
    db = openMemoryDatabase();
    transactions = TransactionRepository(db);
    planning = PlanningRepository(db);
    forecast = ForecastRepository(db);
    addTearDown(db.close);
  });

  DateTime monthsAgo(int months, {int day = 15}) {
    final today = FinancialDate.today();
    return DateTime(today.year, today.month - months, day);
  }

  Future<String> addMovement(
    String accountId, {
    MovementKind kind = MovementKind.expense,
    int amount = 1000,
    DateTime? date,
    String description = 'Movimento',
  }) {
    return transactions.createMovement(
      MovementDraft(
        kind: kind,
        amount: amount,
        date: date ?? FinancialDate.today(),
        accountId: accountId,
        categoryId: kind == MovementKind.income
            ? seededSalaryCategoryId
            : seededFoodCategoryId,
        description: description,
      ),
    );
  }

  Future<String> addCommitment(
    String accountId, {
    int amount = 3000,
    int dueInDays = 3,
    String description = 'Renda',
    PlannedItemKind kind = PlannedItemKind.expense,
  }) {
    return planning.createItem(
      PlannedItemDraft(
        kind: kind,
        amount: amount,
        dueDate: FinancialDate.today().add(Duration(days: dueInDays)),
        description: description,
        accountId: accountId,
        categoryId: kind == PlannedItemKind.income
            ? seededSalaryCategoryId
            : seededFoodCategoryId,
      ),
    );
  }

  Future<int> movementCount() async {
    final rows = await db
        .customSelect('SELECT COUNT(*) AS total FROM transactions')
        .getSingle();
    return rows.read<int>('total');
  }

  test(
    'saldo de partida vem dos movimentos reais, não dos compromissos',
    () async {
      final wallet = await createTestAccount(db, openingBalance: 10000);
      await addMovement(wallet, kind: MovementKind.expense, amount: 3000);
      await addMovement(wallet, kind: MovementKind.income, amount: 1000);
      await addCommitment(wallet, amount: 2000);

      final request = await forecast.buildRequest(
        cutoff: FinancialDate.today(),
      );

      expect(request.openingBalance, 8000);
      expect(request.commitments, hasLength(1));
      expect(request.commitments.single.amount, 2000);
      expect(request.history, isEmpty);
      expect(await movementCount(), 2);
    },
  );

  test('pagamento parcial desconta o pago e não duplica o caixa', () async {
    final wallet = await createTestAccount(db, openingBalance: 10000);
    final itemId = await addCommitment(wallet, amount: 3000);
    await planning.payItem(
      itemId,
      PaymentDraft(
        amount: 1000,
        date: FinancialDate.today(),
        accountId: wallet,
        categoryId: seededFoodCategoryId,
        description: 'Pagamento',
      ),
    );

    final request = await forecast.buildRequest(cutoff: FinancialDate.today());

    expect(request.openingBalance, 9000);
    expect(request.commitments, hasLength(1));
    expect(request.commitments.single.amount, 2000);
    expect(await movementCount(), 1);
  });

  test('compromisso pago fica de fora da previsão', () async {
    final wallet = await createTestAccount(db, openingBalance: 10000);
    final itemId = await addCommitment(wallet, amount: 2000);
    await planning.payItem(
      itemId,
      PaymentDraft(
        amount: 2000,
        date: FinancialDate.today(),
        accountId: wallet,
        categoryId: seededFoodCategoryId,
        description: 'Pagamento',
      ),
    );

    final request = await forecast.buildRequest(cutoff: FinancialDate.today());

    expect(request.openingBalance, 8000);
    expect(request.commitments, isEmpty);
  });

  test('compromisso cancelado fica de fora da previsão', () async {
    final wallet = await createTestAccount(db, openingBalance: 10000);
    final itemId = await addCommitment(wallet, amount: 2000);
    await planning.cancelItem(itemId);

    final request = await forecast.buildRequest(cutoff: FinancialDate.today());

    expect(request.openingBalance, 10000);
    expect(request.commitments, isEmpty);
  });

  test('transferência entre contas próprias não altera a previsão', () async {
    final source = await createTestAccount(
      db,
      name: 'Carteira',
      openingBalance: 10000,
    );
    final destination = await createTestAccount(
      db,
      name: 'Banco',
      openingBalance: 0,
    );
    await transactions.createTransfer(
      TransferDraft(
        sourceAccountId: source,
        destinationAccountId: destination,
        amount: 3000,
        date: FinancialDate.today(),
        description: 'Depósito',
      ),
    );

    final request = await forecast.buildRequest(cutoff: FinancialDate.today());

    expect(request.openingBalance, 10000);
    expect(request.history, isEmpty);
    final balances = await AccountRepository(db)
        .readBalances(until: FinancialDate.today());
    expect(balances.fold(0, (total, entry) => total + entry.balance), 10000);
  });

  test(
    'recorrências entram uma única vez e a sincronização é idempotente',
    () async {
      final wallet = await createTestAccount(db, openingBalance: 10000);
      final today = FinancialDate.today();
      await planning.createRule(
        RecurringRuleDraft(
          kind: PlannedItemKind.expense,
          amount: 1000,
          frequency: RecurrenceFrequency.monthly,
          startDate: today,
          description: 'Renda mensal',
          accountId: wallet,
          categoryId: seededFoodCategoryId,
        ),
      );

      final generatedAt = DateTime.utc(2026, 1, 2, 3, 4, 5);
      final first = await forecast.buildBundle(
        cutoff: today,
        generatedAt: generatedAt,
      );
      final firstItems = await planning.readItems();
      final result90 = first.resultFor(90);
      final dates = result90.commitments.map((line) => line.date).toList();

      expect(first.cutoff, today);
      expect(first.generatedAt, generatedAt);
      expect(firstItems, isNotEmpty);
      expect(result90.commitments, hasLength(firstItems.length));
      expect(dates.toSet(), hasLength(dates.length));
      expect(result90.parameters.horizonDays, 90);
      expect(first.results.keys, containsAll(forecastHorizons));

      final second = await forecast.buildBundle(
        cutoff: today,
        generatedAt: generatedAt,
      );
      expect(second.resultFor(90).commitments, hasLength(firstItems.length));
      expect(await planning.readItems(), hasLength(firstItems.length));
      expect(
        await planning.syncRecurrences(
          horizon: today.add(const Duration(days: 90)),
        ),
        0,
      );
    },
  );

  test('histórico inclui só despesas dos meses completos', () async {
    final wallet = await createTestAccount(db, openingBalance: 10000);
    final other = await createTestAccount(db, name: 'Banco');
    await addMovement(wallet, amount: 3000, date: monthsAgo(2));
    await addMovement(wallet, amount: 2000, date: monthsAgo(1));
    await addMovement(wallet, amount: 5000);
    await addMovement(
      wallet,
      kind: MovementKind.income,
      amount: 4000,
      date: monthsAgo(1),
    );
    await transactions.createTransfer(
      TransferDraft(
        sourceAccountId: wallet,
        destinationAccountId: other,
        amount: 1000,
        date: monthsAgo(1),
        description: 'Transferência',
      ),
    );

    final request = await forecast.buildRequest(cutoff: FinancialDate.today());

    expect(request.openingBalance, 4000);
    expect(request.history, hasLength(2));
    expect(request.history.map((entry) => entry.amount).toSet(), {3000, 2000});
    expect(
      request.history.every(
        (entry) => entry.categoryId == seededFoodCategoryId,
      ),
      isTrue,
    );
  });

  test('correção retroativa recalcula saldo e histórico', () async {
    final wallet = await createTestAccount(db, openingBalance: 10000);

    final before = await forecast.buildRequest(cutoff: FinancialDate.today());
    expect(before.openingBalance, 10000);
    expect(before.history, isEmpty);

    await addMovement(wallet, amount: 2500, date: monthsAgo(2));

    final after = await forecast.buildRequest(cutoff: FinancialDate.today());
    expect(after.openingBalance, 7500);
    expect(after.history, hasLength(1));
    expect(after.history.single.amount, 2500);
  });
}
