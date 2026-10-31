import 'package:financas_pessoais/app/lock/lock_providers.dart';
import 'package:financas_pessoais/core/security/device_auth_providers.dart';
import 'package:financas_pessoais/core/security/device_auth_service.dart';
import 'package:financas_pessoais/features/settings/data/app_settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/database_fixtures.dart';
import '../support/fake_device_auth.dart';
import '../support/widget_harness.dart';

void main() {
  testWidgets('sem preferência a app abre sem pedir desbloqueio', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    final auth = FakeDeviceAuthService();

    await pumpApp(
      tester,
      db,
      overrides: [deviceAuthServiceProvider.overrideWithValue(auth)],
    );

    expect(find.byKey(const Key('app-lock-screen')), findsNothing);
    expect(find.text('Saldo real consolidado'), findsOneWidget);
    expect(auth.calls, 0);

    await disposeApp(tester);
  });

  testWidgets('preferência ligada mostra o bloqueio e revela após autenticar', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await AppSettingsRepository(db).saveLockOnOpen(true);
    final auth = FakeDeviceAuthService();

    await pumpApp(
      tester,
      db,
      overrides: [deviceAuthServiceProvider.overrideWithValue(auth)],
    );

    expect(find.byKey(const Key('app-lock-screen')), findsOneWidget);
    expect(find.text('Nô Dinheru está bloqueada'), findsOneWidget);
    expect(find.byKey(const Key('app-lock-unlock')), findsOneWidget);
    expect(find.byKey(const Key('dashboard-settings')), findsOneWidget);
    expect(
      tester
          .widgetList<AbsorbPointer>(find.byType(AbsorbPointer))
          .any((widget) => widget.absorbing),
      isTrue,
      reason: 'o conteúdo da aplicação não pode aceitar toques',
    );

    auth.complete(DeviceAuthOutcome.success);
    await tester.pump();
    await settle(tester);

    expect(find.byKey(const Key('app-lock-screen')), findsNothing);
    expect(find.text('Saldo real consolidado'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('cancelar mantém o bloqueio e permite tentar novamente', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await AppSettingsRepository(db).saveLockOnOpen(true);
    final auth = FakeDeviceAuthService(
      outcomes: [DeviceAuthOutcome.canceled, DeviceAuthOutcome.success],
    );

    await pumpApp(
      tester,
      db,
      overrides: [deviceAuthServiceProvider.overrideWithValue(auth)],
    );

    expect(find.byKey(const Key('app-lock-screen')), findsOneWidget);
    expect(
      find.text('Desbloqueio cancelado. Tente novamente.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('app-lock-unlock')));
    await settle(tester);

    expect(auth.calls, 2);
    expect(find.byKey(const Key('app-lock-screen')), findsNothing);

    await disposeApp(tester);
  });

  testWidgets('sem credenciais no telefone abre com aviso', (tester) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await AppSettingsRepository(db).saveLockOnOpen(true);
    final auth = FakeDeviceAuthService(supported: false);

    await pumpApp(
      tester,
      db,
      overrides: [deviceAuthServiceProvider.overrideWithValue(auth)],
    );

    expect(find.byKey(const Key('app-lock-screen')), findsOneWidget);
    expect(find.byKey(const Key('app-lock-open-without')), findsOneWidget);
    expect(
      find.text(
        'O bloqueio do telefone não está configurado neste dispositivo.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('app-lock-open-without')));
    await settle(tester);

    expect(find.byKey(const Key('app-lock-screen')), findsNothing);
    expect(find.text('Saldo real consolidado'), findsOneWidget);
    expect(auth.calls, 0);

    await disposeApp(tester);
  });

  testWidgets('volta a bloquear ao regressar do segundo plano', (tester) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await AppSettingsRepository(db).saveLockOnOpen(true);
    final auth = FakeDeviceAuthService(outcomes: [DeviceAuthOutcome.success]);

    await pumpApp(
      tester,
      db,
      overrides: [
        deviceAuthServiceProvider.overrideWithValue(auth),
        appLockReLockAfterProvider.overrideWithValue(Duration.zero),
      ],
    );

    expect(find.byKey(const Key('app-lock-screen')), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await settle(tester);

    expect(find.byKey(const Key('app-lock-screen')), findsOneWidget);

    auth.complete(DeviceAuthOutcome.success);
    await tester.pump();
    await settle(tester);

    expect(find.byKey(const Key('app-lock-screen')), findsNothing);
    expect(auth.calls, 2);

    await disposeApp(tester);
  });

  testWidgets('bloqueio adapta-se a ecrã de telemóvel', (tester) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await AppSettingsRepository(db).saveLockOnOpen(true);
    final auth = FakeDeviceAuthService(outcomes: [DeviceAuthOutcome.canceled]);

    await pumpApp(
      tester,
      db,
      size: const Size(411, 891),
      overrides: [deviceAuthServiceProvider.overrideWithValue(auth)],
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('app-lock-screen')), findsOneWidget);
    expect(find.byKey(const Key('app-lock-unlock')), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('definições ativam e desativam o bloqueio', (tester) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    final auth = FakeDeviceAuthService();

    await pumpApp(
      tester,
      db,
      overrides: [deviceAuthServiceProvider.overrideWithValue(auth)],
    );

    await tapVisible(tester, find.byKey(const Key('dashboard-settings')));
    final switchFinder = find.byKey(const Key('settings-lock-switch'));
    await tester.ensureVisible(switchFinder);
    await tester.pump();

    expect(tester.widget<SwitchListTile>(switchFinder).value, isFalse);

    await tester.tap(switchFinder);
    await settle(tester);

    expect(tester.widget<SwitchListTile>(switchFinder).value, isTrue);
    expect(await AppSettingsRepository(db).loadLockOnOpen(), isTrue);
    expect(find.byKey(const Key('app-lock-screen')), findsNothing);

    await tester.tap(switchFinder);
    await settle(tester);

    expect(tester.widget<SwitchListTile>(switchFinder).value, isFalse);
    expect(await AppSettingsRepository(db).loadLockOnOpen(), isFalse);

    await disposeApp(tester);
  });

  testWidgets('interruptor fica desativado sem credenciais', (tester) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    final auth = FakeDeviceAuthService(supported: false);

    await pumpApp(
      tester,
      db,
      overrides: [deviceAuthServiceProvider.overrideWithValue(auth)],
    );

    await tapVisible(tester, find.byKey(const Key('dashboard-settings')));
    final switchFinder = find.byKey(const Key('settings-lock-switch'));
    await tester.ensureVisible(switchFinder);
    await tester.pump();

    expect(tester.widget<SwitchListTile>(switchFinder).onChanged, isNull);

    await disposeApp(tester);
  });
}
