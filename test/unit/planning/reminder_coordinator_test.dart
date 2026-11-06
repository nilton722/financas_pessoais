import 'package:financas_pessoais/core/database/app_database.dart';
import 'package:financas_pessoais/core/formatters/date_formatter.dart';
import 'package:financas_pessoais/features/planning/data/budget_repository.dart';
import 'package:financas_pessoais/features/planning/data/planning_repository.dart';
import 'package:financas_pessoais/features/planning/data/reminder_coordinator.dart';
import 'package:financas_pessoais/features/planning/domain/planned_item.dart';
import 'package:financas_pessoais/features/settings/data/app_settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/database_fixtures.dart';
import '../../support/domain_fixtures.dart';
import '../../support/fake_notification_gateway.dart';

void main() {
  late AppDatabase db;
  late AppSettingsRepository settings;
  late PlanningRepository planning;
  late FakeNotificationGateway gateway;
  late ReminderCoordinator coordinator;

  setUp(() async {
    db = openMemoryDatabase();
    settings = AppSettingsRepository(db);
    planning = PlanningRepository(db);
    gateway = FakeNotificationGateway();
    coordinator = ReminderCoordinator(
      settingsRepository: settings,
      planningRepository: planning,
      budgetRepository: BudgetRepository(db),
      notificationGateway: gateway,
    );
    addTearDown(db.close);
  });

  Future<void> seedItemDueInTwoDays() async {
    final wallet = await createTestAccount(db);
    await planning.createItem(
      PlannedItemDraft(
        kind: PlannedItemKind.expense,
        amount: 60000,
        dueDate: FinancialDate.today().add(const Duration(days: 2)),
        description: 'Renda',
        accountId: wallet,
        categoryId: seededFoodCategoryId,
      ),
    );
  }

  test('plataforma sem suporte não ativa nem pede permissão', () async {
    gateway.supported = false;

    expect(await coordinator.setEnabled(true), isFalse);

    expect(gateway.permissionRequests, 0);
    expect((await settings.loadReminders()).enabled, isFalse);
    expect(gateway.scheduled, isEmpty);
  });

  test('permissão negada mantém os lembretes desligados', () async {
    gateway.permissionGranted = false;

    expect(await coordinator.setEnabled(true), isFalse);

    expect(gateway.permissionRequests, 1);
    expect((await settings.loadReminders()).enabled, isFalse);
    expect(gateway.scheduled, isEmpty);
  });

  test('ativa, guarda a preferência e agenda os vencimentos', () async {
    await seedItemDueInTwoDays();

    expect(await coordinator.setEnabled(true), isTrue);

    final reminders = await settings.loadReminders();
    expect(reminders.enabled, isTrue);
    expect(reminders.timeLabel, '09:00');
    expect(gateway.scheduled, hasLength(2));
    expect(
      gateway.scheduled.map((request) => request.title),
      unorderedEquals(['Compromisso vence amanhã', 'Compromisso vence hoje']),
    );
    expect(gateway.timeZones, everyElement('Africa/Bissau'));
  });

  test('desligar cancela as notificações pendentes', () async {
    await seedItemDueInTwoDays();
    await coordinator.setEnabled(true);
    expect(gateway.scheduled, isNotEmpty);

    expect(await coordinator.setEnabled(false), isTrue);

    expect((await settings.loadReminders()).enabled, isFalse);
    expect(gateway.scheduled, isEmpty);
    expect(gateway.permissionRequests, 1);
  });

  test('sistema com notificações desligadas não deixa agendamentos', () async {
    await seedItemDueInTwoDays();
    await settings.saveReminders(
      (await settings.loadReminders()).copyWith(enabled: true),
    );
    gateway.systemEnabled = false;

    await coordinator.sync();

    expect(gateway.scheduled, isEmpty);
    expect(gateway.cancelCalls, greaterThan(0));
  });

  test('alterar a hora reagenda no novo horário', () async {
    await seedItemDueInTwoDays();
    await coordinator.setEnabled(true);

    await coordinator.setTime(18, 30);

    expect((await settings.loadReminders()).timeLabel, '18:30');
    expect(gateway.scheduled, hasLength(2));
    expect(
      gateway.scheduled.every(
        (request) => request.when.hour == 18 && request.when.minute == 30,
      ),
      isTrue,
    );
  });

  test('sincronizações repetidas usam os mesmos identificadores', () async {
    await seedItemDueInTwoDays();
    await coordinator.setEnabled(true);
    final firstIds = gateway.scheduled.map((request) => request.id).toList();

    await coordinator.sync();

    expect(gateway.scheduled.map((request) => request.id), firstIds);
    expect(gateway.cancelCalls, greaterThanOrEqualTo(2));
  });
}
