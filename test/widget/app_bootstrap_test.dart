import 'package:financas_pessoais/app/app.dart';
import 'package:financas_pessoais/core/database/database_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/database_fixtures.dart';
import '../support/widget_harness.dart';

void main() {
  testWidgets('arranca no painel com saldo consolidado e navegação inferior', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);

    await pumpApp(tester, db);

    expect(find.text('Finanças Pessoais'), findsOneWidget);
    expect(find.text('Saldo consolidado'), findsOneWidget);
    expect(find.text('Ainda sem contas'), findsOneWidget);
    expect(find.text('Rendimentos do mês'), findsOneWidget);
    expect(find.text('Despesas do mês'), findsOneWidget);
    expect(find.textContaining('esquema v4'), findsOneWidget);
    expect(find.textContaining('Africa/Bissau'), findsOneWidget);

    for (final label in [
      'Painel',
      'Movimentos',
      'Contas',
      'Categorias',
      'Planeamento',
    ]) {
      expect(find.text(label), findsWidgets);
    }

    await disposeApp(tester);
  });

  testWidgets('mostra falha legível quando a base não abre', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith(
            (ref) => throw StateError('falha simulada'),
          ),
        ],
        child: const FinancasApp(),
      ),
    );
    await settle(tester);

    expect(
      find.text('Não foi possível abrir a base de dados local.'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(FilledButton, 'Tentar novamente'),
      findsOneWidget,
    );

    await disposeApp(tester);
  });
}
