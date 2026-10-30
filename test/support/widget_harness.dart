import 'package:financas_pessoais/app/app.dart';
import 'package:financas_pessoais/core/database/app_database.dart';
import 'package:financas_pessoais/core/database/database_providers.dart';
import 'package:financas_pessoais/core/files/app_files.dart';
import 'package:financas_pessoais/core/files/app_files_provider.dart';
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
///
/// [filesRoot] substitui a pasta de dados da aplicação por uma pasta
/// temporária nos testes de backup e exportação.
Future<void> pumpApp(
  WidgetTester tester,
  AppDatabase db, {
  AppFilesRootResolver? filesRoot,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        if (filesRoot != null)
          appFilesRootResolverProvider.overrideWithValue(filesRoot),
      ],
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

/// Alterna tempo simulado e real até [condition] aparecer. Necessário para
/// operações de ficheiro: cada `await` de I/O só continua no `pump` seguinte.
/// O `pump` avança o relógio simulado para que animações (diálogos, rotas)
/// terminem enquanto o I/O real progride.
Future<void> pumpDisk(
  WidgetTester tester,
  Finder condition, {
  int attempts = 80,
}) async {
  for (var attempt = 0; attempt < attempts; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (condition.evaluate().isNotEmpty) {
      break;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
  }
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
