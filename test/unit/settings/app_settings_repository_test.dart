import 'package:drift/drift.dart' show Value;
import 'package:financas_pessoais/core/database/app_database.dart';
import 'package:financas_pessoais/features/settings/data/app_settings_repository.dart';
import 'package:financas_pessoais/features/settings/domain/app_settings.dart';
import 'package:financas_pessoais/features/settings/domain/reminder_settings.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/database_fixtures.dart';

void main() {
  test('lê as configurações semeadas', () async {
    final db = openMemoryDatabase();
    addTearDown(db.close);

    final settings = await AppSettingsRepository(db).load();
    expect(settings.currencyCode, 'XOF');
    expect(settings.locale, 'pt_PT');
    expect(settings.timeZone, 'Africa/Bissau');
  });

  test('grava e volta a ler configurações', () async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    final repository = AppSettingsRepository(db);

    await repository.save(
      const AppSettings(
        currencyCode: 'XOF',
        locale: 'pt_PT',
        timeZone: 'Africa/Dakar',
      ),
    );

    final settings = await repository.load();
    expect(settings.timeZone, 'Africa/Dakar');
    expect((await db.select(db.appSettings).get()).length, 3);
  });

  test('preferência de bloqueio começa desligada e persiste', () async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    final repository = AppSettingsRepository(db);

    expect(await repository.loadLockOnOpen(), isFalse);

    await repository.saveLockOnOpen(true);

    expect(await repository.loadLockOnOpen(), isTrue);
    expect((await repository.load()).timeZone, 'Africa/Bissau');
    expect((await db.select(db.appSettings).get()).length, 4);

    await repository.saveLockOnOpen(false);

    expect(await repository.loadLockOnOpen(), isFalse);
    expect((await db.select(db.appSettings).get()).length, 4);
  });

  test('lembretes começam desligados às 09:00', () async {
    final db = openMemoryDatabase();
    addTearDown(db.close);

    final reminders = await AppSettingsRepository(db).loadReminders();

    expect(reminders.enabled, isFalse);
    expect(reminders.hour, 9);
    expect(reminders.minute, 0);
    expect(reminders.timeLabel, '09:00');
  });

  test('grava e volta a ler a preferência de lembretes', () async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    final repository = AppSettingsRepository(db);

    await repository.saveReminders(
      const ReminderSettings(enabled: true, hour: 18, minute: 30),
    );

    final reminders = await repository.loadReminders();
    expect(reminders.enabled, isTrue);
    expect(reminders.timeLabel, '18:30');
    expect((await repository.load()).timeZone, 'Africa/Bissau');
    expect((await db.select(db.appSettings).get()).length, 5);
  });

  test('hora guardada inválida volta ao valor predefinido', () async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    final repository = AppSettingsRepository(db);
    await repository.saveReminders(
      const ReminderSettings(enabled: true, hour: 9, minute: 0),
    );
    await (db.update(db.appSettings)..where(
          (table) => table.key.equals(AppSettingsRepository.reminderTimeKey),
        ))
        .write(const AppSettingsCompanion(value: Value('25:99')));

    final reminders = await repository.loadReminders();

    expect(reminders.enabled, isTrue);
    expect(reminders.hour, 9);
    expect(reminders.minute, 0);
  });
}
