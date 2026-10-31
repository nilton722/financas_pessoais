import 'dart:async';

import 'package:financas_pessoais/app/app.dart';
import 'package:financas_pessoais/app/app_startup.dart';
import 'package:financas_pessoais/core/database/database_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/database_fixtures.dart';
import '../support/widget_harness.dart';

void main() {
  testWidgets('splash apresenta a marca e aguarda a inicialização real', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);

    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final startup = Completer<void>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          appStartupProvider.overrideWith((ref) => startup.future),
        ],
        child: const FinancasApp(),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('splash-screen')), findsOneWidget);
    expect(find.byKey(const Key('splash-icon-tile')), findsOneWidget);
    expect(find.byKey(const Key('splash-icon')), findsOneWidget);
    expect(find.text('Nô Dinheru'), findsWidgets);
    expect(find.text('O teu dinheiro, sob controlo.'), findsOneWidget);
    expect(find.text('Finanças pessoais • Guiné-Bissau'), findsOneWidget);

    for (final key in const [
      Key('splash-name'),
      Key('splash-slogan'),
      Key('splash-tagline'),
    ]) {
      final text = tester.widget<Text>(find.byKey(key));
      expect(
        text.style?.decoration,
        TextDecoration.none,
        reason:
            'o texto do splash não deve herdar o estilo de erro do WidgetsApp',
      );
    }

    await tester.pump(const Duration(seconds: 2));
    expect(
      find.byKey(const Key('splash-screen')),
      findsOneWidget,
      reason: 'o splash não pode sair antes de a inicialização terminar',
    );

    startup.complete();
    await tester.pump();
    await settle(tester);

    expect(find.byKey(const Key('splash-screen')), findsNothing);
    expect(find.text('Saldo real consolidado'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('splash adapta-se a ecrãs pequenos sem sobrepor conteúdo', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);

    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final startup = Completer<void>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          appStartupProvider.overrideWith((ref) => startup.future),
        ],
        child: const FinancasApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1100));

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('splash-screen')), findsOneWidget);

    startup.complete();
    await settle(tester);

    expect(find.byKey(const Key('splash-screen')), findsNothing);
    await disposeApp(tester);
  });
}
