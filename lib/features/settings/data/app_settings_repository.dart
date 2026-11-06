import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/time.dart';
import '../domain/app_settings.dart';
import '../domain/reminder_settings.dart';

class AppSettingsRepository {
  AppSettingsRepository(this._db);

  final AppDatabase _db;

  static const String currencyCodeKey = 'currency_code';
  static const String localeKey = 'locale';
  static const String timeZoneKey = 'time_zone';
  static const String lockOnOpenKey = 'lock_on_open';
  static const String remindersEnabledKey = 'reminders_enabled';
  static const String reminderTimeKey = 'reminder_time';

  Future<AppSettings> load() async {
    final rows = await _db.select(_db.appSettings).get();
    final values = {for (final row in rows) row.key: row.value};
    return AppSettings(
      currencyCode:
          values[currencyCodeKey] ?? AppSettings.defaults.currencyCode,
      locale: values[localeKey] ?? AppSettings.defaults.locale,
      timeZone: values[timeZoneKey] ?? AppSettings.defaults.timeZone,
    );
  }

  Future<void> save(AppSettings settings) async {
    final now = utcNowIsoString();
    final entries = {
      currencyCodeKey: settings.currencyCode,
      localeKey: settings.locale,
      timeZoneKey: settings.timeZone,
    };
    await _db.batch((batch) {
      batch.insertAll(_db.appSettings, [
        for (final entry in entries.entries)
          AppSettingsCompanion.insert(
            key: entry.key,
            value: entry.value,
            updatedAt: now,
          ),
      ], mode: InsertMode.insertOrReplace);
    });
  }

  Future<bool> loadLockOnOpen() async {
    final row = await (_db.select(
      _db.appSettings,
    )..where((table) => table.key.equals(lockOnOpenKey))).getSingleOrNull();
    return row?.value == 'true';
  }

  Future<void> saveLockOnOpen(bool enabled) async {
    await _db
        .into(_db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: lockOnOpenKey,
            value: enabled ? 'true' : 'false',
            updatedAt: utcNowIsoString(),
          ),
        );
  }

  Future<ReminderSettings> loadReminders() async {
    final rows =
        await (_db.select(_db.appSettings)..where(
              (table) => table.key.isIn([remindersEnabledKey, reminderTimeKey]),
            ))
            .get();
    final values = {for (final row in rows) row.key: row.value};
    return ReminderSettings.fromStored(
      enabled: values[remindersEnabledKey] == 'true',
      storedTime: values[reminderTimeKey],
    );
  }

  Future<void> saveReminders(ReminderSettings settings) async {
    final now = utcNowIsoString();
    await _db.batch((batch) {
      batch.insertAll(_db.appSettings, [
        AppSettingsCompanion.insert(
          key: remindersEnabledKey,
          value: settings.enabled ? 'true' : 'false',
          updatedAt: now,
        ),
        AppSettingsCompanion.insert(
          key: reminderTimeKey,
          value:
              '${settings.hour.toString().padLeft(2, '0')}:'
              '${settings.minute.toString().padLeft(2, '0')}',
          updatedAt: now,
        ),
      ], mode: InsertMode.insertOrReplace);
    });
  }
}
