import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:financas_pessoais/core/database/app_database.dart';
import 'package:financas_pessoais/core/database/migrations/schema_v1.dart';
import 'package:financas_pessoais/core/database/migrations/schema_v2.dart';
import 'package:financas_pessoais/core/database/migrations/schema_v3.dart';
import 'package:financas_pessoais/core/database/migrations/schema_v4.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/database_fixtures.dart';

void main() {
  group('esquema atual', () {
    late AppDatabase db;

    setUp(() => db = openMemoryDatabase());
    tearDown(() => db.close());

    Future<Set<String>> schemaObjects(String type) async {
      final rows = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = ? "
            "AND name NOT LIKE 'sqlite_%'",
            variables: [Variable.withString(type)],
          )
          .get();
      return rows.map((row) => row.read<String>('name')).toSet();
    }

    test('cria todas as tabelas da v4', () async {
      expect(
        await schemaObjects('table'),
        containsAll(<String>[
          'accounts',
          'categories',
          'transactions',
          'app_settings',
          'schema_migrations',
          'planned_items',
          'planned_item_payments',
          'recurring_rules',
          'recurring_occurrences',
          'budgets',
          'savings_goals',
          'debts',
          'debt_payments',
        ]),
      );
      expect(await db.readUserVersion(), SchemaV4.version);
    });

    test('regista as migrações v1–v4 uma única vez', () async {
      final migrations = await db.select(db.schemaMigrations).get();
      expect(migrations.map((migration) => migration.version), [
        SchemaV1.version,
        SchemaV2.version,
        SchemaV3.version,
        SchemaV4.version,
      ]);
      expect(
        migrations.every((migration) => migration.appliedAt.endsWith('Z')),
        isTrue,
      );
    });

    test('cria os índices de consulta', () async {
      expect(
        await schemaObjects('index'),
        containsAll(<String>[
          'idx_transactions_date',
          'idx_transactions_account',
          'idx_transactions_category',
          'idx_transactions_kind',
          'uq_categories_active_name',
          'idx_planned_items_due_date',
          'idx_planned_items_status',
          'idx_planned_item_payments_item',
          'idx_recurring_rules_active',
          'idx_recurring_occurrences_rule',
          'idx_budgets_period',
          'idx_savings_goals_archived',
          'idx_debts_status',
          'idx_debt_payments_debt',
        ]),
      );
    });

    test('ativa foreign keys em cada abertura', () async {
      final row = await db.customSelect('PRAGMA foreign_keys').getSingle();
      expect(row.data.values.first, 1);
    });
  });

  group('migração de ficheiro v1 para v4', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('financas_migration');
    });

    tearDown(() async {
      if (directory.existsSync()) {
        await directory.delete(recursive: true);
      }
    });

    /// Recria o estado de uma base v1: remove tabelas e registos das versões
    /// seguintes e baixa o `user_version`, como numa instalação antiga.
    Future<void> downgradeToV1(AppDatabase db) async {
      const tables = [
        'debt_payments',
        'debts',
        'savings_goals',
        'budgets',
        'recurring_occurrences',
        'planned_item_payments',
        'recurring_rules',
        'planned_items',
      ];
      for (final table in tables) {
        await db.customStatement('DROP TABLE IF EXISTS $table');
      }
      await db.customStatement(
        'DELETE FROM schema_migrations WHERE version > 1',
      );
      await db.customStatement('PRAGMA user_version = 1');
    }

    test('preserva dados existentes e aplica v2–v4', () async {
      final file = File('${directory.path}/legacy.sqlite');

      final legacy = AppDatabase(NativeDatabase(file));
      await legacy
          .into(legacy.accounts)
          .insert(accountCompanion(id: 'conta-antiga'));
      await legacy
          .into(legacy.transactions)
          .insert(
            transactionCompanion(
              transactionFields(
                id: 'mov-antigo',
                accountId: 'conta-antiga',
                amount: 1500,
              ),
            ),
          );
      await downgradeToV1(legacy);
      await legacy.close();

      final migrated = AppDatabase(NativeDatabase(file));
      addTearDown(migrated.close);
      final account = await (migrated.select(
        migrated.accounts,
      )..where((row) => row.id.equals('conta-antiga'))).getSingle();
      expect(account.name, 'Conta conta-antiga');
      final transaction = await (migrated.select(
        migrated.transactions,
      )..where((row) => row.id.equals('mov-antigo'))).getSingle();
      expect(transaction.amount, 1500);

      expect(await migrated.readUserVersion(), SchemaV4.version);
      final versions = await migrated.select(migrated.schemaMigrations).get();
      expect(versions.map((row) => row.version), [1, 2, 3, 4]);
      final tables = await migrated
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name NOT LIKE 'sqlite_%'",
          )
          .get();
      expect(
        tables.map((row) => row.read<String>('name')),
        containsAll(<String>[
          'planned_items',
          'recurring_rules',
          'budgets',
          'savings_goals',
          'debts',
          'debt_payments',
        ]),
      );
    });

    test('reabrir uma base já migrada não duplica registos', () async {
      final file = File('${directory.path}/reopen.sqlite');

      final first = AppDatabase(NativeDatabase(file));
      await first.close();

      final second = AppDatabase(NativeDatabase(file));
      addTearDown(second.close);
      final versions = await second.select(second.schemaMigrations).get();
      expect(versions.length, 4);
      expect(await second.readUserVersion(), SchemaV4.version);
    });
  });
}
