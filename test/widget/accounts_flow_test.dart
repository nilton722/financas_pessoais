import 'package:financas_pessoais/core/formatters/date_formatter.dart';
import 'package:financas_pessoais/core/formatters/money_formatter.dart';
import 'package:financas_pessoais/features/accounts/data/account_repository.dart';
import 'package:financas_pessoais/features/accounts/domain/account.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/database_fixtures.dart';
import '../support/widget_harness.dart';

void main() {
  testWidgets('navega entre separadores e cria uma conta', (tester) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await pumpApp(tester, db);

    await tapNavigation(tester, 'Contas');
    expect(find.text('Sem contas'), findsOneWidget);
    expect(
      find.widgetWithText(FloatingActionButton, 'Nova conta'),
      findsOneWidget,
    );

    await tapVisible(
      tester,
      find.widgetWithText(FloatingActionButton, 'Nova conta'),
    );
    expect(find.widgetWithText(AppBar, 'Nova conta'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Carteira');
    await tester.enterText(find.byType(TextField).at(1), '5000');

    await tapVisible(tester, find.widgetWithText(FilledButton, 'Guardar'));

    expect(find.text('Conta criada.'), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Contas'), findsOneWidget);
    expect(find.text('Carteira'), findsOneWidget);
    expect(find.text(MoneyFormatter.formatXof(5000)), findsWidgets);

    await disposeApp(tester);

    final stored = await AccountRepository(db)
        .readBalances(until: FinancialDate.today());
    expect(stored.single.account.name, 'Carteira');
    expect(stored.single.account.openingBalance, 5000);
    expect(stored.single.account.type, AccountType.cash);
  });

  testWidgets('formulário de conta mostra erros de validação', (tester) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await pumpApp(tester, db);

    await tapNavigation(tester, 'Contas');
    await tapVisible(
      tester,
      find.widgetWithText(FloatingActionButton, 'Nova conta'),
    );

    await tapVisible(tester, find.widgetWithText(FilledButton, 'Guardar'));

    expect(find.text('Indique o nome da conta.'), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Nova conta'), findsOneWidget);

    await disposeApp(tester);

    expect(
      await AccountRepository(db).readBalances(until: FinancialDate.today()),
      isEmpty,
    );
  });

  testWidgets('separador de categorias lista as predefinidas', (tester) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await pumpApp(tester, db);

    await tapNavigation(tester, 'Categorias');

    expect(find.widgetWithText(AppBar, 'Categorias'), findsOneWidget);
    expect(find.text('Rendimentos'), findsOneWidget);
    expect(find.text('Despesas'), findsOneWidget);
    expect(find.text('Salário'), findsOneWidget);
    expect(find.text('Alimentação'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('separador de movimentos começa vazio', (tester) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await pumpApp(tester, db);

    await tapNavigation(tester, 'Movimentos');

    expect(find.text('Sem movimentos'), findsOneWidget);
    expect(
      find.widgetWithText(FloatingActionButton, 'Novo movimento'),
      findsOneWidget,
    );

    await disposeApp(tester);
  });
}
