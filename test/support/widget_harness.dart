import 'package:financas_pessoais/app/app.dart';
import 'package:financas_pessoais/core/database/app_database.dart';
import 'package:financas_pessoais/core/database/database_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Teto para `pumpAndSettle`: um temporizador pendente deve falhar depressa
/// em vez de bloquear 10 minutos.
Future<void> settle(WidgetTester tester) => tester.pumpAndSettle(
  const Duration(milliseconds: 100),
  EnginePhase.sendSemanticsUpdate,
  const Duration(seconds: 15),
);

/// Ecrã alto o suficiente para o painel e os formulários ficarem visíveis,
/// evitando falhas de toque por conteúdo fora da área renderizada.
Future<void> pumpApp(WidgetTester tester, AppDatabase db) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: const FinancasApp(),
    ),
  );
  await settle(tester);
}

Future<void> tapNavigation(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await settle(tester);
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await settle(tester);
  await tester.tap(finder);
  await settle(tester);
}

/// Deixa o SnackBar expirar e desmonta a árvore. O fecho dos streams do drift
/// agenda um temporizador de duração zero; é preciso um `pump` extra para o
/// executar antes do fim do teste.
Future<void> disposeApp(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 100));
}
