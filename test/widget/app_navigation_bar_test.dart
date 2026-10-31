import 'package:financas_pessoais/app/shell/app_navigation_bar.dart';
import 'package:financas_pessoais/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _destinations = <({IconData icon, String label})>[
  (icon: Icons.dashboard_outlined, label: 'Painel'),
  (icon: Icons.swap_vert, label: 'Movimentos'),
  (icon: Icons.account_balance_wallet_outlined, label: 'Contas'),
  (icon: Icons.category_outlined, label: 'Categorias'),
  (icon: Icons.event_note_outlined, label: 'Plano'),
];

Future<List<int>> _pumpBar(
  WidgetTester tester, {
  required Size size,
  required double textScaleFactor,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScaleFactor;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });

  final taps = <int>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        bottomNavigationBar: AppNavigationBar(
          selectedIndex: 0,
          onDestinationSelected: taps.add,
          destinations: _destinations,
        ),
      ),
    ),
  );
  return taps;
}

void main() {
  testWidgets(
    'etiquetas ficam numa linha em ecrã estreito com texto ampliado',
    (tester) async {
      await _pumpBar(tester, size: const Size(320, 568), textScaleFactor: 1.3);

      expect(tester.takeException(), isNull);

      for (final destination in _destinations) {
        final label = find.descendant(
          of: find.byType(AppNavigationBar),
          matching: find.text(destination.label),
        );
        expect(label, findsOneWidget);
        expect(tester.widget<Text>(label).maxLines, 1);
      }
    },
  );

  testWidgets('destino continua a responder ao toque', (tester) async {
    final taps = await _pumpBar(
      tester,
      size: const Size(320, 568),
      textScaleFactor: 1.3,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(AppNavigationBar),
        matching: find.text('Movimentos'),
      ),
    );
    await tester.pumpAndSettle();

    expect(taps, [1]);
  });
}
