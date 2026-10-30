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
}
