import 'package:financas_pessoais/core/database/app_database.dart' hide Budget;
import 'package:financas_pessoais/core/errors/app_failure.dart';
import 'package:financas_pessoais/core/formatters/date_formatter.dart';
import 'package:financas_pessoais/features/planning/data/budget_repository.dart';
import 'package:financas_pessoais/features/planning/domain/budget.dart';
import 'package:financas_pessoais/features/transactions/data/transaction_repository.dart';
import 'package:financas_pessoais/features/transactions/domain/movement.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/database_fixtures.dart';
import '../../support/domain_fixtures.dart';

void main() {
  late AppDatabase db;
  late TransactionRepository transactions;
  late BudgetRepository budgets;

  setUp(() {
    db = openMemoryDatabase();
    transactions = TransactionRepository(db);
    budgets = BudgetRepository(db);
  });

  tearDown(() => db.close());

  test(
    'gasto soma despesas do mês e ignora transferências e rendimentos',
    () async {
      final today = FinancialDate.today();
      final month = DateTime(today.year, today.month);
      final wallet = await createTestAccount(db, name: 'Carteira');
      final savings = await createTestAccount(db, name: 'Poupança');

      await transactions.createMovement(
        MovementDraft(
          kind: MovementKind.expense,
          amount: 2000,
          date: today,
          accountId: wallet,
          categoryId: seededFoodCategoryId,
          description: 'Mercado',
        ),
      );
      await transactions.createMovement(
        MovementDraft(
          kind: MovementKind.income,
          amount: 5000,
          date: today,
          accountId: wallet,
          categoryId: seededSalaryCategoryId,
          description: 'Salário',
        ),
      );
      await transactions.createTransfer(
        TransferDraft(
          sourceAccountId: wallet,
          destinationAccountId: savings,
          amount: 1000,
          date: today,
          description: 'Reserva',
        ),
      );
      await transactions.createMovement(
        MovementDraft(
          kind: MovementKind.expense,
          amount: 700,
          date: DateTime(today.year, today.month, 0),
          accountId: wallet,
          categoryId: seededFoodCategoryId,
          description: 'Mês anterior',
        ),
      );

      await budgets.save(
        BudgetDraft(
          categoryId: seededFoodCategoryId,
          limitAmount: 3000,
          periodStart: month,
        ),
      );

      final budget = (await budgets.readMonth(month)).single;
      expect(budget.spent, 2000);
      expect(budget.remaining, 1000);
      expect(budget.isExceeded, isFalse);
      expect(budget.progress, closeTo(2 / 3, 0.0001));
    },
  );

  test('despesa eliminada deixa de contar para o orçamento', () async {
    final today = FinancialDate.today();
    final month = DateTime(today.year, today.month);
    final wallet = await createTestAccount(db);
    final movementId = await transactions.createMovement(
      MovementDraft(
        kind: MovementKind.expense,
        amount: 1500,
        date: today,
        accountId: wallet,
        categoryId: seededFoodCategoryId,
        description: 'Mercado',
      ),
    );
    await budgets.save(
      BudgetDraft(
        categoryId: seededFoodCategoryId,
        limitAmount: 2000,
        periodStart: month,
      ),
    );

    expect((await budgets.readMonth(month)).single.spent, 1500);
    await transactions.softDelete(movementId);
    expect((await budgets.readMonth(month)).single.spent, 0);
  });

  test('guardar duas vezes atualiza o limite sem duplicar o período', () async {
    final month = DateTime(
      FinancialDate.today().year,
      FinancialDate.today().month,
    );
    final firstId = await budgets.save(
      BudgetDraft(
        categoryId: seededFoodCategoryId,
        limitAmount: 3000,
        periodStart: month,
      ),
    );
    final secondId = await budgets.save(
      BudgetDraft(
        categoryId: seededFoodCategoryId,
        limitAmount: 4500,
        periodStart: month,
      ),
    );

    expect(secondId, firstId);
    expect(await db.select(db.budgets).get(), hasLength(1));
    expect((await budgets.readMonth(month)).single.limitAmount, 4500);
  });

  test('rejeita orçamento para categoria de rendimento', () async {
    await expectLater(
      budgets.save(
        BudgetDraft(
          categoryId: seededSalaryCategoryId,
          limitAmount: 1000,
          periodStart: FinancialDate.today(),
        ),
      ),
      throwsA(isA<AppFailure>()),
    );
  });

  test('orçamento excedido mantém percentagem acima de 100', () {
    final budget = Budget(
      id: 'b',
      categoryId: 'c',
      categoryName: 'Alimentação',
      periodStart: DateTime(2026, 10),
      limitAmount: 1000,
      spent: 1300,
    );
    expect(budget.isExceeded, isTrue);
    expect(budget.remaining, -300);
    expect(budget.percent, 130);
    expect(budget.progress, 1);
  });

  test('período normaliza para o primeiro dia do mês', () {
    expect(BudgetPeriod.monthStart(DateTime(2026, 10, 30)), DateTime(2026, 10));
    expect(BudgetPeriod.monthEnd(DateTime(2026, 2, 3)), DateTime(2026, 2, 28));
    expect(BudgetPeriod.dbValue(DateTime(2026, 10, 30)), '2026-10-01');
  });
}
