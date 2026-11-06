import 'package:financas_pessoais/core/formatters/date_formatter.dart';
import 'package:financas_pessoais/features/transactions/data/transaction_repository.dart';
import 'package:financas_pessoais/features/transactions/domain/movement.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/database_fixtures.dart';
import '../support/domain_fixtures.dart';
import '../support/widget_harness.dart';

void main() {
  testWidgets('pesquisa, envia para a lixeira e restaura movimentos', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    final accountId = await createTestAccount(
      db,
      name: 'Carteira',
      openingBalance: 5000,
    );
    final repository = TransactionRepository(db);
    await repository.createMovement(
      MovementDraft(
        kind: MovementKind.income,
        amount: 2500,
        date: FinancialDate.today(),
        accountId: accountId,
        categoryId: seededSalaryCategoryId,
        description: 'Salário de outubro',
      ),
    );
    final expenseId = await repository.createMovement(
      MovementDraft(
        kind: MovementKind.expense,
        amount: 800,
        date: FinancialDate.today(),
        accountId: accountId,
        categoryId: seededFoodCategoryId,
        description: 'Mercado',
        notes: 'Feira semanal',
      ),
    );

    await pumpApp(tester, db);
    await tapNavigation(tester, 'Movimentos');

    expect(find.text('Salário de outubro'), findsOneWidget);
    expect(find.text('Mercado'), findsOneWidget);

    await tapVisible(tester, find.byTooltip('Pesquisar'));
    await tester.enterText(find.byKey(const Key('movement-search')), 'feira');
    await settle(tester);

    expect(find.text('Mercado'), findsOneWidget);
    expect(find.text('Salário de outubro'), findsNothing);

    await tapVisible(tester, find.byTooltip('Fechar pesquisa'));
    expect(find.text('Salário de outubro'), findsOneWidget);

    await tapVisible(tester, find.byKey(Key('movement-menu-$expenseId')));
    await tapVisible(tester, find.text('Mover para a lixeira'));
    await tapVisible(tester, find.text('Mover para a lixeira'));

    expect(find.text('Mercado'), findsNothing);
    expect(
      find.textContaining('Movimento movido para a lixeira'),
      findsOneWidget,
    );

    await tapVisible(tester, find.byTooltip('Lixeira'));
    expect(find.widgetWithText(AppBar, 'Lixeira'), findsOneWidget);
    expect(find.text('Mercado'), findsOneWidget);

    final restore = find.byKey(Key('trash-restore-$expenseId'));
    await tester.ensureVisible(restore);
    await settle(tester);
    await tester.tap(restore);
    await pumpDisk(tester, find.textContaining('Movimento restaurado'));

    expect(find.textContaining('Movimento restaurado'), findsOneWidget);
    expect(
      await repository.readMovements(const MovementFilter()),
      hasLength(2),
    );

    await disposeApp(tester);
  });
}
