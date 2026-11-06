import 'package:financas_pessoais/core/formatters/date_formatter.dart';
import 'package:financas_pessoais/core/formatters/money_formatter.dart';
import 'package:financas_pessoais/features/accounts/data/account_repository.dart';
import 'package:financas_pessoais/features/planning/data/budget_repository.dart';
import 'package:financas_pessoais/features/planning/data/debt_repository.dart';
import 'package:financas_pessoais/features/planning/data/planning_repository.dart';
import 'package:financas_pessoais/features/planning/data/savings_goal_repository.dart';
import 'package:financas_pessoais/features/planning/domain/budget.dart';
import 'package:financas_pessoais/features/planning/domain/planned_item.dart';
import 'package:financas_pessoais/features/planning/domain/recurrence.dart';
import 'package:financas_pessoais/features/transactions/data/transaction_repository.dart';
import 'package:financas_pessoais/features/transactions/domain/movement.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/database_fixtures.dart';
import '../support/domain_fixtures.dart';
import '../support/widget_harness.dart';

void main() {
  testWidgets('separador de planeamento apresenta áreas e estado vazio', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await pumpApp(tester, db);

    await tapNavigation(tester, 'Plano');

    expect(find.widgetWithText(AppBar, 'Planeamento'), findsOneWidget);
    for (final label in [
      'Compromissos',
      'Orçamentos',
      'Recorrências',
      'Metas de poupança',
      'Dívidas',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Sem compromissos pendentes'), findsOneWidget);
    expect(find.textContaining('Sem orçamentos em'), findsOneWidget);
    expect(find.text('Sem regras recorrentes'), findsOneWidget);
    expect(find.text('Sem metas definidas'), findsOneWidget);
    expect(find.text('Sem dívidas em aberto'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('cria e paga um compromisso sem duplicar o caixa', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await createTestAccount(db, name: 'Carteira', openingBalance: 5000);
    await pumpApp(tester, db);

    await tapNavigation(tester, 'Plano');
    await tapVisible(tester, find.text('Compromissos'));
    expect(find.text('Sem compromissos pendentes'), findsOneWidget);

    await tapVisible(
      tester,
      find.widgetWithText(FloatingActionButton, 'Novo compromisso'),
    );
    expect(find.widgetWithText(AppBar, 'Novo compromisso'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '2000');
    await tester.enterText(find.byType(TextField).at(1), 'Renda');
    await settle(tester);

    await tapVisible(tester, find.byType(DropdownButton<String>).first);
    await tapVisible(tester, find.text('Carteira').last);
    await tapVisible(tester, find.byType(DropdownButton<String>).at(1));
    await tapVisible(tester, find.text('Alimentação').last);

    await tapVisible(tester, find.widgetWithText(FilledButton, 'Guardar'));

    expect(find.text('Compromisso criado.'), findsOneWidget);
    expect(find.text('Renda'), findsOneWidget);

    await tapVisible(tester, find.byTooltip('Opções'));
    await tapVisible(tester, find.text('Pagar'));
    expect(find.widgetWithText(AppBar, 'Pagar compromisso'), findsOneWidget);

    await tapVisible(tester, find.byType(DropdownButton<String>).first);
    await tapVisible(tester, find.text('Carteira').last);
    await tapVisible(tester, find.byType(DropdownButton<String>).at(1));
    await tapVisible(tester, find.text('Alimentação').last);

    await tapVisible(
      tester,
      find.widgetWithText(FilledButton, 'Registar pagamento'),
    );

    expect(find.text('Pagamento registado.'), findsOneWidget);
    expect(find.text('Sem compromissos pendentes'), findsOneWidget);

    await tapVisible(tester, find.byTooltip('Mostrar liquidados'));
    expect(find.text('Renda'), findsOneWidget);
    expect(find.textContaining('Pago'), findsWidgets);

    await disposeApp(tester);

    final balances = await AccountRepository(db)
        .readBalances(until: FinancialDate.today());
    expect(balances.single.balance, 3000);

    final movements = await TransactionRepository(db)
        .readMovements(const MovementFilter());
    expect(movements, hasLength(1));
    expect(movements.single.movement.amount, 2000);
    expect(movements.single.movement.kind, MovementKind.expense);

    final items = await PlanningRepository(db).readItems();
    expect(items.single.paidTotal, 2000);
    expect(items.single.effectiveStatus, PlannedItemStatus.paid);
  });

  testWidgets('orçamento acompanha apenas despesas reais da categoria', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    final accountId = await createTestAccount(db, name: 'Carteira');
    await TransactionRepository(db).createMovement(
      MovementDraft(
        kind: MovementKind.expense,
        amount: 3000,
        date: FinancialDate.today(),
        accountId: accountId,
        categoryId: seededFoodCategoryId,
        description: 'Mercado',
      ),
    );
    await pumpApp(tester, db);

    await tapNavigation(tester, 'Plano');
    await tapVisible(tester, find.text('Orçamentos'));
    expect(find.textContaining('Sem orçamentos em'), findsOneWidget);

    await tapVisible(
      tester,
      find.widgetWithText(FloatingActionButton, 'Novo orçamento'),
    );
    await tapVisible(tester, find.byType(DropdownButton<String>).first);
    await tapVisible(tester, find.text('Alimentação').last);
    await tester.enterText(find.byType(TextField).first, '5000');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Guardar'));

    expect(find.text('Orçamento guardado.'), findsOneWidget);
    expect(find.text('Gasto'), findsOneWidget);
    expect(find.text(MoneyFormatter.formatXof(3000)), findsWidgets);
    expect(find.text(MoneyFormatter.formatXof(5000)), findsWidgets);
    expect(find.text('60%'), findsOneWidget);
    expect(find.text('Restam'), findsOneWidget);
    expect(find.text(MoneyFormatter.formatXof(2000)), findsOneWidget);

    await disposeApp(tester);

    final budgets = await BudgetRepository(db).readMonth(FinancialDate.today());
    expect(budgets.single.spent, 3000);
    expect(budgets.single.limitAmount, 5000);
  });

  testWidgets('alterar limite fecha o diálogo sem erro de controller', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await createTestAccount(db, name: 'Carteira');
    await BudgetRepository(db).save(
      BudgetDraft(
        categoryId: seededFoodCategoryId,
        limitAmount: 5000,
        periodStart: FinancialDate.today(),
      ),
    );
    await pumpApp(tester, db);

    await tapNavigation(tester, 'Plano');
    await tapVisible(tester, find.text('Orçamentos'));
    await tapVisible(tester, find.byType(PopupMenuButton<String>));
    await tapVisible(tester, find.text('Alterar limite'));

    expect(find.text('Limite mensal'), findsOneWidget);
    expect(find.text('5000'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '7500');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Guardar'));
    await pumpDisk(tester, find.text('Limite atualizado.'));
    expect(find.text('Limite atualizado.'), findsOneWidget);

    // Reabrir e cancelar também não pode usar um controller já libertado.
    await tapVisible(tester, find.byType(PopupMenuButton<String>));
    await tapVisible(tester, find.text('Alterar limite'));
    await tapVisible(tester, find.widgetWithText(TextButton, 'Cancelar'));
    expect(find.text('Limite mensal'), findsNothing);

    await disposeApp(tester);

    final budgets = await BudgetRepository(db).readMonth(FinancialDate.today());
    expect(budgets.single.limitAmount, 7500);
  });

  testWidgets('dívida só altera o caixa através do pagamento', (tester) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await createTestAccount(db, name: 'Carteira', openingBalance: 5000);
    await pumpApp(tester, db);

    await tapNavigation(tester, 'Plano');
    await tapVisible(tester, find.text('Dívidas'));
    expect(find.text('Sem dívidas'), findsOneWidget);

    await tapVisible(
      tester,
      find.widgetWithText(FloatingActionButton, 'Nova dívida'),
    );
    await tester.enterText(find.byType(TextField).at(0), 'Empréstimo');
    await tester.enterText(find.byType(TextField).at(2), '1500');
    await settle(tester);
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Guardar'));

    expect(find.text('Dívida criada.'), findsOneWidget);
    expect(find.text('Empréstimo · A pagar'), findsOneWidget);

    await tapVisible(tester, find.byTooltip('Opções'));
    await tapVisible(tester, find.text('Registar pagamento'));
    expect(find.widgetWithText(AppBar, 'Pagar dívida'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '500');
    await settle(tester);
    await tapVisible(tester, find.byType(DropdownButton<String>).first);
    await tapVisible(tester, find.text('Carteira').last);
    await tapVisible(tester, find.byType(DropdownButton<String>).at(1));
    await tapVisible(tester, find.text('Alimentação').last);

    await tapVisible(
      tester,
      find.widgetWithText(FilledButton, 'Registar pagamento'),
    );

    expect(find.text('Pagamento registado.'), findsOneWidget);
    expect(
      find.text(MoneyFormatter.formatXof(1000)),
      findsWidgets,
      reason: 'o resumo e o cartão da dívida mostram o pendente',
    );

    await disposeApp(tester);

    final balances = await AccountRepository(db)
        .readBalances(until: FinancialDate.today());
    expect(balances.single.balance, 4500);

    final debts = await DebtRepository(db).readDebts();
    expect(debts.single.paidTotal, 500);
    expect(debts.single.remaining, 1000);

    final movements = await TransactionRepository(db)
        .readMovements(const MovementFilter());
    expect(movements, hasLength(1));
    expect(movements.single.movement.amount, 500);
  });

  testWidgets('meta de poupança progresso vem do saldo real da conta', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await createTestAccount(db, name: 'Carteira', openingBalance: 5000);
    await pumpApp(tester, db);

    await tapNavigation(tester, 'Plano');
    await tapVisible(tester, find.text('Metas de poupança'));
    expect(find.text('Sem metas'), findsOneWidget);

    await tapVisible(
      tester,
      find.widgetWithText(FloatingActionButton, 'Nova meta'),
    );
    await tester.enterText(find.byType(TextField).at(0), 'Viagem');
    await tester.enterText(find.byType(TextField).at(1), '10000');
    await settle(tester);
    await tapVisible(tester, find.byType(DropdownButton<String>).first);
    await tapVisible(tester, find.text('Carteira').last);
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Guardar'));

    expect(find.text('Meta criada.'), findsOneWidget);
    expect(find.text('Viagem'), findsOneWidget);
    expect(find.text('Poupado'), findsOneWidget);
    expect(find.text(MoneyFormatter.formatXof(5000)), findsWidgets);
    expect(find.text('Objetivo'), findsOneWidget);
    expect(find.text(MoneyFormatter.formatXof(10000)), findsWidgets);
    expect(find.text('50%'), findsOneWidget);

    await disposeApp(tester);

    final goals = await SavingsGoalRepository(db).readAll();
    expect(goals.single.currentAmount, 5000);
    expect(goals.single.targetAmount, 10000);
  });

  testWidgets('recorrência mensal gera ocorrências idempotentes', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await pumpApp(tester, db);

    await tapNavigation(tester, 'Plano');
    await tapVisible(tester, find.text('Recorrências'));
    expect(find.text('Sem recorrências'), findsOneWidget);

    await tapVisible(
      tester,
      find.widgetWithText(FloatingActionButton, 'Nova recorrência'),
    );
    await tester.enterText(find.byType(TextField).at(0), '2000');
    await tester.enterText(find.byType(TextField).at(1), 'Renda mensal');
    await settle(tester);
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Guardar'));

    expect(find.text('Recorrência criada.'), findsOneWidget);
    expect(find.text('Renda mensal'), findsOneWidget);
    expect(find.textContaining('Mensal'), findsWidgets);

    final generated = (await PlanningRepository(db).readItems()).length;
    expect(generated, greaterThan(0));

    // Deixa o SnackBar anterior expirar para o próximo ficar visível.
    await tester.pump(const Duration(seconds: 5));
    await tapVisible(tester, find.byTooltip('Gerar ocorrências até 90 dias'));
    expect(find.text('Sem novas ocorrências.'), findsOneWidget);
    expect((await PlanningRepository(db).readItems()).length, generated);

    await tapNavigation(tester, 'Plano');
    expect(find.textContaining('$generated pendentes'), findsOneWidget);
    await tapVisible(tester, find.text('Compromissos'));
    expect(find.text('Renda mensal'), findsNWidgets(generated));

    await disposeApp(tester);

    final rules = await PlanningRepository(db).readRules();
    expect(rules, hasLength(1));
    expect(rules.single.frequency, RecurrenceFrequency.monthly);
    expect(rules.single.description, 'Renda mensal');
  });

  testWidgets('edita a frequência de uma recorrência já materializada', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await pumpApp(tester, db);

    await tapNavigation(tester, 'Plano');
    await tapVisible(tester, find.text('Recorrências'));
    await tapVisible(
      tester,
      find.widgetWithText(FloatingActionButton, 'Nova recorrência'),
    );
    await tester.enterText(find.byType(TextField).at(0), '2000');
    await tester.enterText(find.byType(TextField).at(1), 'Renda mensal');
    await settle(tester);
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Guardar'));
    expect(find.text('Recorrência criada.'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tapVisible(tester, find.text('Renda mensal'));
    expect(find.widgetWithText(AppBar, 'Editar recorrência'), findsOneWidget);
    expect(
      find.textContaining('reconstrói as ocorrências futuras'),
      findsOneWidget,
    );

    await tapVisible(
      tester,
      find.byType(DropdownButton<RecurrenceFrequency>).first,
    );
    await tapVisible(tester, find.text('Semanal').last);
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Guardar'));

    expect(find.text('Reconstruir ocorrências futuras?'), findsOneWidget);
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Reconstruir'));

    expect(find.text('Recorrência atualizada.'), findsOneWidget);
    final rules = await PlanningRepository(db).readRules();
    expect(rules.single.frequency, RecurrenceFrequency.weekly);

    await disposeApp(tester);
  });
}
