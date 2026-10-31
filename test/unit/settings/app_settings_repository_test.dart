import 'package:financas_pessoais/features/settings/data/app_settings_repository.dart';
import 'package:financas_pessoais/features/settings/domain/app_settings.dart';
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
}
