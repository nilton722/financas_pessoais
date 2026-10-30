import 'dart:io';

import 'package:drift/native.dart';
import 'package:financas_pessoais/core/database/app_database.dart';
import 'package:financas_pessoais/core/database/seeds/default_seeds.dart';
import 'package:financas_pessoais/features/settings/data/app_settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/database_fixtures.dart';

void main() {
  test('semeia categorias de sistema e configurações iniciais', () async {
    final db = openMemoryDatabase();
    addTearDown(db.close);

    final categories = await db.select(db.categories).get();
    expect(categories.length, seedCategories.length);
    expect(categories.every((category) => category.isSystem), isTrue);
    expect(categories.where((c) => c.kind == 'income').length, 3);
    expect(categories.where((c) => c.kind == 'expense').length, 8);

    final settings = await AppSettingsRepository(db).load();
    expect(settings.currencyCode, 'XOF');
    expect(settings.locale, 'pt_PT');
    expect(settings.timeZone, 'Africa/Bissau');
  });

  test('não cria contas nem movimentos fictícios', () async {
    final db = openMemoryDatabase();
    addTearDown(db.close);

    expect(await db.select(db.accounts).get(), isEmpty);
    expect(await db.select(db.transactions).get(), isEmpty);
  });

  test('inicialização repetida não duplica seeds nem migrações', () async {
    final directory = await Directory.systemTemp.createTemp('financas_seed');
    final file = File('${directory.path}/teste.sqlite');

    final first = AppDatabase(NativeDatabase(file));
    await first.select(first.categories).get();
    await first.close();

    final second = AppDatabase(NativeDatabase(file));
    final categories = await second.select(second.categories).get();
    final settings = await second.select(second.appSettings).get();
    final migrations = await second.select(second.schemaMigrations).get();
    await second.close();

    expect(categories.length, seedCategories.length);
    expect(settings.length, seedSettings.length);
    expect(migrations.length, 4);

    await directory.delete(recursive: true);
  });
}
