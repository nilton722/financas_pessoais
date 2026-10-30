import 'package:financas_pessoais/features/transactions/data/transaction_repository.dart';
import 'package:financas_pessoais/features/transactions/domain/movement.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/database_fixtures.dart';
import '../support/domain_fixtures.dart';
import '../support/widget_harness.dart';

void main() {
  testWidgets('valida campos obrigatórios do movimento', (tester) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await pumpApp(tester, db);

    await tapVisible(
      tester,
      find.widgetWithText(FilledButton, 'Novo movimento'),
    );
    expect(find.widgetWithText(AppBar, 'Novo movimento'), findsOneWidget);

    await tapVisible(tester, find.widgetWithText(FilledButton, 'Guardar'));

    expect(find.text('Indique o montante em FCFA.'), findsOneWidget);
    expect(find.text('Escolha a conta.'), findsOneWidget);
    expect(find.text('Escolha a categoria.'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('regista um rendimento e atualiza o saldo', (tester) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await createTestAccount(db, name: 'Carteira', openingBalance: 5000);

    await pumpApp(tester, db);

    await tapVisible(
      tester,
      find.widgetWithText(FilledButton, 'Novo movimento'),
    );

    await tester.enterText(find.byType(TextField).first, '2500');
    await settle(tester);

    await tapVisible(tester, find.byType(DropdownButton<String>).first);
    await tapVisible(tester, find.text('Carteira').last);

    await tapVisible(tester, find.byType(DropdownButton<String>).at(1));
    await tapVisible(tester, find.text('Salário').last);

    await tapVisible(tester, find.widgetWithText(FilledButton, 'Guardar'));

    expect(find.text('Movimento registado.'), findsOneWidget);

    await disposeApp(tester);

    final stored = await TransactionRepository(db)
        .readMovements(const MovementFilter());
    expect(stored.single.movement.kind, MovementKind.income);
    expect(stored.single.movement.amount, 2500);
    expect(stored.single.categoryName, 'Salário');
    expect(stored.single.accountName, 'Carteira');
  });

  testWidgets('rejeita montante com casas decimais', (tester) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await createTestAccount(db, name: 'Carteira');

    await pumpApp(tester, db);
    await tapVisible(
      tester,
      find.widgetWithText(FilledButton, 'Novo movimento'),
    );

    await tester.enterText(find.byType(TextField).first, '12.5');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Guardar'));

    expect(
      find.text('Use um número inteiro de FCFA, sem casas decimais.'),
      findsOneWidget,
    );

    await disposeApp(tester);

    expect(
      await TransactionRepository(db).readMovements(const MovementFilter()),
      isEmpty,
    );
  });
}
