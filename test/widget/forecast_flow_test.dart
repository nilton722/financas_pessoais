import 'package:financas_pessoais/core/formatters/date_formatter.dart';
import 'package:financas_pessoais/core/formatters/money_formatter.dart';
import 'package:financas_pessoais/features/planning/data/planning_repository.dart';
import 'package:financas_pessoais/features/planning/domain/planned_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/database_fixtures.dart';
import '../support/domain_fixtures.dart';
import '../support/widget_harness.dart';

void main() {
  testWidgets('painel abre a previsão com pressupostos e limitações', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await pumpApp(tester, db);

    expect(find.text('Previsão (30 dias)'), findsOneWidget);
    expect(
      find.textContaining(
        'Saldo projetado ${MoneyFormatter.formatXof(0)} em 30 dias',
      ),
      findsOneWidget,
    );

    await tapVisible(tester, find.text('Previsão (30 dias)'));

    expect(find.widgetWithText(AppBar, 'Previsão'), findsOneWidget);
    expect(find.text('Saldo projetado'), findsOneWidget);
    expect(find.text('Pressupostos'), findsOneWidget);
    expect(find.text('Qualidade dos dados e limitações'), findsOneWidget);
    expect(find.text('Sem compromissos'), findsOneWidget);
    expect(find.textContaining('Data de corte:'), findsOneWidget);
    await tester.scrollUntilVisible(
      forecastAlgorithmFooter('forecast-1'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(forecastAlgorithmFooter('forecast-1'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('saldo negativo é assinalado no painel e na previsão', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    final wallet = await createTestAccount(db, openingBalance: 1000);
    await PlanningRepository(db).createItem(
      PlannedItemDraft(
        kind: PlannedItemKind.expense,
        amount: 3000,
        dueDate: FinancialDate.today().add(const Duration(days: 3)),
        description: 'Renda',
        accountId: wallet,
        categoryId: seededFoodCategoryId,
      ),
    );
    await pumpApp(tester, db);

    expect(find.byIcon(Icons.warning_amber_outlined), findsOneWidget);

    await tapVisible(tester, find.text('Previsão (30 dias)'));

    expect(find.text('Possível saldo negativo'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('forecastClosingBalance'))).data,
      MoneyFormatter.formatXof(-2000),
    );
    expect(find.text('Renda'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('horizontes de 7, 30 e 90 dias recalculam o saldo', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    final wallet = await createTestAccount(db, openingBalance: 10000);
    await PlanningRepository(db).createItem(
      PlannedItemDraft(
        kind: PlannedItemKind.expense,
        amount: 5000,
        dueDate: FinancialDate.today().add(const Duration(days: 20)),
        description: 'Renda',
        accountId: wallet,
        categoryId: seededFoodCategoryId,
      ),
    );
    await pumpApp(tester, db);

    await tapVisible(tester, find.text('Previsão (30 dias)'));

    String closing() => tester
        .widget<Text>(find.byKey(const Key('forecastClosingBalance')))
        .data!;

    expect(closing(), MoneyFormatter.formatXof(5000));

    await tapVisible(tester, find.text('7 dias'));
    expect(closing(), MoneyFormatter.formatXof(10000));

    await tapVisible(tester, find.text('90 dias'));
    expect(closing(), MoneyFormatter.formatXof(5000));

    await disposeApp(tester);
  });
}

/// O rodapé junta vários valores numa única linha de texto.
Finder forecastAlgorithmFooter(String version) =>
    find.textContaining('Algoritmo: $version');
