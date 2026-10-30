import 'package:financas_pessoais/core/formatters/date_formatter.dart';
import 'package:financas_pessoais/core/formatters/money_formatter.dart';
import 'package:financas_pessoais/features/planning/data/budget_repository.dart';
import 'package:financas_pessoais/features/planning/data/planning_repository.dart';
import 'package:financas_pessoais/features/planning/data/savings_goal_repository.dart';
import 'package:financas_pessoais/features/planning/domain/budget.dart';
import 'package:financas_pessoais/features/planning/domain/planned_item.dart';
import 'package:financas_pessoais/features/planning/domain/savings_goal.dart';
import 'package:financas_pessoais/features/transactions/data/transaction_repository.dart';
import 'package:financas_pessoais/features/transactions/domain/movement.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/database_fixtures.dart';
import '../support/domain_fixtures.dart';
import '../support/widget_harness.dart';

void main() {
  testWidgets('painel separa saldo real de projetado e resume planeamento', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    final wallet = await createTestAccount(
      db,
      name: 'Carteira',
      openingBalance: 100000,
    );
    await TransactionRepository(db).createMovement(
      MovementDraft(
        kind: MovementKind.expense,
        amount: 30000,
        date: FinancialDate.today(),
        accountId: wallet,
        categoryId: seededFoodCategoryId,
        description: 'Mercado',
      ),
    );
    await BudgetRepository(db).save(
      BudgetDraft(
        categoryId: seededFoodCategoryId,
        limitAmount: 50000,
        periodStart: FinancialDate.today(),
      ),
    );
    await PlanningRepository(db).createItem(
      PlannedItemDraft(
        kind: PlannedItemKind.expense,
        amount: 5000,
        dueDate: FinancialDate.today().add(const Duration(days: 3)),
        description: 'Renda',
      ),
    );
    await SavingsGoalRepository(db).create(
      SavingsGoalDraft(
        name: 'Viagem',
        targetAmount: 200000,
        linkedAccountId: wallet,
      ),
    );

    await pumpApp(tester, db);

    expect(find.text('Saldo real consolidado'), findsOneWidget);
    expect(
      find.text(MoneyFormatter.formatXof(70000)),
      findsWidgets,
      reason: 'saldo após a despesa de 30 000',
    );
    expect(find.text('Projetado'), findsOneWidget);
    expect(
      find.textContaining('Saldo projetado'),
      findsOneWidget,
      reason: 'a previsão é identificada como valor projetado',
    );
    expect(find.text('Planeamento'), findsWidgets);
    expect(
      find.textContaining(
        'Gasto ${MoneyFormatter.formatXof(30000)} de '
        '${MoneyFormatter.formatXof(50000)}',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('1 a pagar'), findsOneWidget);
    expect(find.textContaining(MoneyFormatter.formatXof(5000)), findsWidgets);
    expect(find.text('Metas de poupança'), findsOneWidget);
    expect(
      find.textContaining(
        '1 meta(s) · ${MoneyFormatter.formatXof(70000)} de '
        '${MoneyFormatter.formatXof(200000)}',
      ),
      findsOneWidget,
    );

    await tapVisible(tester, find.byKey(const Key('dashboard-budget')));
    expect(find.widgetWithText(AppBar, 'Orçamentos'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('sem planeamento o painel mostra estados vazios legíveis', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await pumpApp(tester, db);

    expect(find.text('Saldo real consolidado'), findsOneWidget);
    expect(find.textContaining('Sem orçamentos em'), findsOneWidget);
    expect(find.text('Sem compromissos pendentes'), findsOneWidget);
    expect(find.text('Sem metas ativas'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('leitor de ecrã distingue saldo real e estimativa', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await pumpApp(tester, db);
    final handle = tester.ensureSemantics();

    expect(
      find.bySemanticsLabel(RegExp('Saldo real consolidado')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp('Estimativa\\. Previsão a 30 dias')),
      findsOneWidget,
    );

    handle.dispose();
    await disposeApp(tester);
  });
}
