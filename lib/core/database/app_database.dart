import 'package:drift/drift.dart';

import '../errors/app_failure.dart';
import '../utils/time.dart';
import 'migrations/schema_v1.dart';
import 'migrations/schema_v2.dart';
import 'migrations/schema_v3.dart';
import 'migrations/schema_v4.dart';
import 'seeds/default_seeds.dart';
import 'tables/accounts.dart';
import 'tables/app_settings.dart';
import 'tables/budgets.dart';
import 'tables/categories.dart';
import 'tables/debts.dart';
import 'tables/planned_items.dart';
import 'tables/recurring.dart';
import 'tables/savings_goals.dart';
import 'tables/schema_migrations.dart';
import 'tables/transactions.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Accounts,
    Categories,
    Transactions,
    AppSettings,
    SchemaMigrations,
    PlannedItems,
    PlannedItemPayments,
    RecurringRules,
    RecurringOccurrences,
    Budgets,
    SavingsGoals,
    Debts,
    DebtPayments,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Nome sem extensão: `driftDatabase` acrescenta `.sqlite` ao criar o
  /// ficheiro, pelo que o resultado é `financas_pessoais.sqlite`.
  static const String databaseName = 'financas_pessoais';

  @override
  int get schemaVersion => SchemaV4.version;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await SchemaV1.apply(this);
      await SchemaV2.apply(this);
      await SchemaV3.apply(this);
      await SchemaV4.apply(this);
    },
    onUpgrade: (m, from, to) async {
      // Cada passo é aditivo e preserva os dados existentes; nunca recriar a
      // base (ADR-009). A ordem respeita as referências entre tabelas.
      if (from < SchemaV2.version) {
        await m.createTable(plannedItems);
        await m.createTable(plannedItemPayments);
        await m.createTable(recurringRules);
        await m.createTable(recurringOccurrences);
        await SchemaV2.apply(this);
      }
      if (from < SchemaV3.version) {
        await m.createTable(budgets);
        await SchemaV3.apply(this);
      }
      if (from < SchemaV4.version) {
        await m.createTable(savingsGoals);
        await m.createTable(debts);
        await m.createTable(debtPayments);
        await SchemaV4.apply(this);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      final pragma = await customSelect('PRAGMA foreign_keys').getSingle();
      if (pragma.data.values.first != 1) {
        throw const AppFailure('SQLite abriu sem foreign keys ativas.');
      }
      await _seedDefaults();
    },
  );

  Future<int> readUserVersion() async {
    final row = await customSelect('PRAGMA user_version').getSingle();
    return row.data.values.first as int;
  }

  Future<void> _seedDefaults() async {
    final now = utcNowIsoString();
    await batch((batch) {
      batch.insertAll(categories, [
        for (final seed in seedCategories)
          CategoriesCompanion.insert(
            id: seed.id,
            name: seed.name,
            kind: seed.kind,
            iconKey: Value(seed.iconKey),
            colorValue: const Value(seedCategoryColor),
            isSystem: const Value(true),
            createdAt: now,
            updatedAt: now,
          ),
      ], mode: InsertMode.insertOrIgnore);
      batch.insertAll(appSettings, [
        for (final entry in seedSettings.entries)
          AppSettingsCompanion.insert(
            key: entry.key,
            value: entry.value,
            updatedAt: now,
          ),
      ], mode: InsertMode.insertOrIgnore);
    });
  }
}
