import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:financas_pessoais/core/database/app_database.dart';
import 'package:financas_pessoais/core/database/migrations/schema_v1.dart';
import 'package:financas_pessoais/core/database/migrations/schema_v2.dart';
import 'package:financas_pessoais/core/database/migrations/schema_v3.dart';
import 'package:financas_pessoais/core/database/migrations/schema_v4.dart';
import 'package:financas_pessoais/core/formatters/date_formatter.dart';
import 'package:financas_pessoais/features/accounts/data/account_repository.dart';
import 'package:financas_pessoais/features/planning/data/budget_repository.dart';
import 'package:financas_pessoais/features/planning/data/debt_repository.dart';
import 'package:financas_pessoais/features/planning/data/planning_repository.dart';
import 'package:financas_pessoais/features/planning/data/savings_goal_repository.dart';
import 'package:financas_pessoais/features/planning/domain/budget.dart';
import 'package:financas_pessoais/features/planning/domain/debt.dart';
import 'package:financas_pessoais/features/planning/domain/planned_item.dart';
import 'package:financas_pessoais/features/planning/domain/savings_goal.dart';
import 'package:financas_pessoais/features/transactions/data/transaction_repository.dart';
import 'package:financas_pessoais/features/transactions/domain/movement.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/database_fixtures.dart';
import '../../support/domain_fixtures.dart';

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

  group('migração de ficheiro v3 para v4', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp(
        'financas_migration_v3',
      );
    });

    tearDown(() async {
      if (directory.existsSync()) {
        await directory.delete(recursive: true);
      }
    });

    /// A v4 só acrescenta índices. Reverter para v3 remove-os e baixa a versão,
    /// simulando uma instalação anterior com dados de todas as áreas.
    Future<void> downgradeToV3(AppDatabase db) async {
      for (final index in [
        'idx_savings_goals_archived',
        'idx_debts_status',
        'idx_debt_payments_debt',
      ]) {
        await db.customStatement('DROP INDEX IF EXISTS $index');
      }
      await db.customStatement(
        'DELETE FROM schema_migrations WHERE version > 3',
      );
      await db.customStatement('PRAGMA user_version = 3');
    }

    Future<int> countRows(AppDatabase db, String table) async {
      final row = await db
          .customSelect('SELECT COUNT(*) AS total FROM "$table"')
          .getSingle();
      return row.read<int>('total');
    }

    test('preserva planeamento, orçamentos, metas e dívidas', () async {
      final file = File('${directory.path}/v3.sqlite');

      final legacy = AppDatabase(NativeDatabase(file));
      final wallet = await createTestAccount(legacy, openingBalance: 10000);
      await TransactionRepository(legacy).createMovement(
        MovementDraft(
          kind: MovementKind.expense,
          amount: 2500,
          date: FinancialDate.today(),
          accountId: wallet,
          categoryId: seededFoodCategoryId,
          description: 'Mercado',
        ),
      );
      final itemId = await PlanningRepository(legacy).createItem(
        PlannedItemDraft(
          kind: PlannedItemKind.expense,
          amount: 3000,
          dueDate: FinancialDate.today().add(const Duration(days: 5)),
          description: 'Renda',
          accountId: wallet,
          categoryId: seededFoodCategoryId,
        ),
      );
      await PlanningRepository(legacy).payItem(
        itemId,
        PaymentDraft(
          amount: 1000,
          date: FinancialDate.today(),
          accountId: wallet,
          categoryId: seededFoodCategoryId,
          description: 'Pagamento renda',
        ),
      );
      await BudgetRepository(legacy).save(
        BudgetDraft(
          categoryId: seededFoodCategoryId,
          limitAmount: 4000,
          periodStart: DateTime.now(),
        ),
      );
      await SavingsGoalRepository(legacy).create(
        SavingsGoalDraft(
          name: 'Emergência',
          targetAmount: 5000,
          linkedAccountId: wallet,
        ),
      );
      final debtId = await DebtRepository(legacy).create(
        DebtDraft(
          kind: DebtKind.payable,
          description: 'Empréstimo',
          originalAmount: 2000,
        ),
      );
      await DebtRepository(legacy).pay(
        debtId,
        DebtPaymentDraft(
          amount: 500,
          date: FinancialDate.today(),
          accountId: wallet,
          categoryId: seededFoodCategoryId,
        ),
      );

      await downgradeToV3(legacy);
      expect(await legacy.readUserVersion(), SchemaV3.version);
      await legacy.close();

      final migrated = AppDatabase(NativeDatabase(file));
      addTearDown(migrated.close);

      expect(await migrated.readUserVersion(), SchemaV4.version);
      final versions = await migrated.select(migrated.schemaMigrations).get();
      expect(versions.map((row) => row.version), [1, 2, 3, 4]);

      expect(await countRows(migrated, 'accounts'), 1);
      expect(
        await countRows(migrated, 'transactions'),
        3,
        reason: 'despesa, pagamento do compromisso e pagamento da dívida',
      );
      expect(await countRows(migrated, 'planned_item_payments'), 1);
      expect(await countRows(migrated, 'debt_payments'), 1);
      expect(await countRows(migrated, 'budgets'), 1);
      expect(await countRows(migrated, 'savings_goals'), 1);
      expect(await countRows(migrated, 'debts'), 1);

      final balances = await AccountRepository(migrated)
          .readBalances(until: FinancialDate.today());
      expect(balances.single.balance, 6000);

      final item = (await PlanningRepository(migrated).readItems()).single;
      expect(item.paidTotal, 1000);
      expect(item.remaining, 2000);

      final debt = (await DebtRepository(migrated).readDebts()).single;
      expect(debt.paidTotal, 500);
      expect(debt.remaining, 1500);

      final goal = (await SavingsGoalRepository(migrated).readAll()).single;
      expect(goal.currentAmount, 6000);

      final budget = (await BudgetRepository(
        migrated,
      ).readMonth(DateTime.now())).single;
      expect(budget.limitAmount, 4000);
      expect(budget.spent, 4000);

      final indexes = await migrated
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' "
            "AND name IN (?, ?, ?)",
            variables: [
              Variable.withString('idx_savings_goals_archived'),
              Variable.withString('idx_debts_status'),
              Variable.withString('idx_debt_payments_debt'),
            ],
          )
          .get();
      expect(indexes, hasLength(3));
    });
  });
}
