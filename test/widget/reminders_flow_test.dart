import 'package:financas_pessoais/features/planning/presentation/reminder_providers.dart';
import 'package:financas_pessoais/features/settings/data/app_settings_repository.dart';
import 'package:financas_pessoais/features/settings/domain/reminder_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/database_fixtures.dart';
import '../support/fake_notification_gateway.dart';
import '../support/widget_harness.dart';

void main() {
  testWidgets('definições ativam lembretes e persistem a preferência', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    final gateway = FakeNotificationGateway();

    await pumpApp(
      tester,
      db,
      overrides: [localNotificationGatewayProvider.overrideWithValue(gateway)],
    );

    await tapVisible(tester, find.byKey(const Key('dashboard-settings')));
    final switchFinder = find.byKey(const Key('settings-reminders-switch'));
    await scrollToVisible(tester, switchFinder);

    expect(tester.widget<SwitchListTile>(switchFinder).value, isFalse);

    await tester.tap(switchFinder);
    await settle(tester);

    expect(tester.widget<SwitchListTile>(switchFinder).value, isTrue);
    expect(gateway.permissionRequests, 1);
    expect((await AppSettingsRepository(db).loadReminders()).enabled, isTrue);
    expect(find.text('Lembretes ativados.'), findsOneWidget);

    await tester.tap(switchFinder);
    await settle(tester);

    expect(tester.widget<SwitchListTile>(switchFinder).value, isFalse);
    expect((await AppSettingsRepository(db).loadReminders()).enabled, isFalse);
    expect(find.text('Lembretes desativados.'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('permissão negada mantém os lembretes desligados', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    final gateway = FakeNotificationGateway(permissionGranted: false);

    await pumpApp(
      tester,
      db,
      overrides: [localNotificationGatewayProvider.overrideWithValue(gateway)],
    );

    await tapVisible(tester, find.byKey(const Key('dashboard-settings')));
    final switchFinder = find.byKey(const Key('settings-reminders-switch'));
    await scrollToVisible(tester, switchFinder);

    await tester.tap(switchFinder);
    await settle(tester);

    expect(tester.widget<SwitchListTile>(switchFinder).value, isFalse);
    expect((await AppSettingsRepository(db).loadReminders()).enabled, isFalse);
    expect(
      find.textContaining('Confirme a permissão de notificações'),
      findsOneWidget,
    );

    await disposeApp(tester);
  });

  testWidgets('plataforma sem suporte desativa a opção', (tester) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    final gateway = FakeNotificationGateway(supported: false);

    await pumpApp(
      tester,
      db,
      overrides: [localNotificationGatewayProvider.overrideWithValue(gateway)],
    );

    await tapVisible(tester, find.byKey(const Key('dashboard-settings')));
    final switchFinder = find.byKey(const Key('settings-reminders-switch'));
    await scrollToVisible(tester, switchFinder);

    expect(tester.widget<SwitchListTile>(switchFinder).onChanged, isNull);
    expect(find.text('Disponível apenas em Android e iOS.'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('preferência restaurada sem permissão mostra aviso', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await AppSettingsRepository(
      db,
    ).saveReminders(const ReminderSettings(enabled: true, hour: 9, minute: 0));
    final gateway = FakeNotificationGateway(systemEnabled: false);

    await pumpApp(
      tester,
      db,
      overrides: [localNotificationGatewayProvider.overrideWithValue(gateway)],
    );

    await tapVisible(tester, find.byKey(const Key('dashboard-settings')));
    final switchFinder = find.byKey(const Key('settings-reminders-switch'));
    await scrollToVisible(tester, switchFinder);

    expect(tester.widget<SwitchListTile>(switchFinder).value, isTrue);
    expect(
      find.textContaining('Permissão de notificações desligada'),
      findsOneWidget,
    );

    await disposeApp(tester);
  });
}
