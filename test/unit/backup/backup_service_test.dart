import 'dart:io';

import 'package:financas_pessoais/core/backup/backup_crypto.dart';
import 'package:financas_pessoais/core/backup/backup_format.dart';
import 'package:financas_pessoais/core/backup/backup_service.dart';
import 'package:financas_pessoais/core/backup/backup_storage.dart';
import 'package:financas_pessoais/core/database/app_database.dart';
import 'package:financas_pessoais/core/errors/app_failure.dart';
import 'package:financas_pessoais/core/files/app_files.dart';
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
import 'package:financas_pessoais/features/settings/data/app_settings_repository.dart';
import 'package:financas_pessoais/features/settings/domain/app_settings.dart';
import 'package:financas_pessoais/features/transactions/data/transaction_repository.dart';
import 'package:financas_pessoais/features/transactions/domain/movement.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/database_fixtures.dart';
import '../../support/domain_fixtures.dart';

void main() {
  late Directory tempDir;
  late AppDatabase db;
  late BackupStorage storage;
  late BackupService service;
  late String wallet;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('financas_backup_test');
    db = openMemoryDatabase();
    storage = BackupStorage(AppFiles(rootResolver: () async => tempDir));
    service = BackupService(db, storage);
    wallet = await createTestAccount(db, openingBalance: 10000);
    addTearDown(() async {
      await db.close();
      await tempDir.delete(recursive: true);
    });
  });

  Future<void> seedData() async {
    final transactions = TransactionRepository(db);
    await transactions.createMovement(
      MovementDraft(
        kind: MovementKind.expense,
        amount: 2500,
        date: FinancialDate.today(),
        accountId: wallet,
        categoryId: seededFoodCategoryId,
        description: 'Mercado; pão "quente"',
        notes: 'Linha 1\nLinha 2',
      ),
    );
    final itemId = await PlanningRepository(db).createItem(
      PlannedItemDraft(
        kind: PlannedItemKind.expense,
        amount: 3000,
        dueDate: FinancialDate.today().add(const Duration(days: 5)),
        description: 'Renda',
        accountId: wallet,
        categoryId: seededFoodCategoryId,
      ),
    );
    await PlanningRepository(db).payItem(
      itemId,
      PaymentDraft(
        amount: 1000,
        date: FinancialDate.today(),
        accountId: wallet,
        categoryId: seededFoodCategoryId,
        description: 'Pagamento renda',
      ),
    );
    await SavingsGoalRepository(db).create(
      SavingsGoalDraft(
        name: 'Emergência',
        targetAmount: 5000,
        linkedAccountId: wallet,
      ),
    );
    final debtId = await DebtRepository(db).create(
      DebtDraft(
        kind: DebtKind.payable,
        description: 'Empréstimo',
        originalAmount: 2000,
      ),
    );
    await DebtRepository(db).pay(
      debtId,
      DebtPaymentDraft(
        amount: 500,
        date: FinancialDate.today(),
        accountId: wallet,
        categoryId: seededFoodCategoryId,
      ),
    );
    await BudgetRepository(db).save(
      BudgetDraft(
        categoryId: seededFoodCategoryId,
        limitAmount: 4000,
        periodStart: DateTime.now(),
      ),
    );
    await AppSettingsRepository(db).save(
      const AppSettings(
        currencyCode: 'XOF',
        locale: 'pt_PT',
        timeZone: 'Africa/Bissau',
      ),
    );
  }

  test('backup restaura numa base limpa com IDs, saldos e relações', () async {
    await seedData();
    final created = await service.createBackup(
      now: DateTime.utc(2026, 10, 30, 12, 0),
    );

    expect(created.isValid, isTrue);
    expect(File(created.file.path).existsSync(), isTrue);
    expect(created.snapshot!.counts['accounts'], 1);
    expect(created.snapshot!.counts['transactions'], 3);
    expect(created.snapshot!.counts['planned_item_payments'], 1);
    expect(created.snapshot!.counts['debt_payments'], 1);
    expect(created.snapshot!.counts['budgets'], 1);
    expect(created.snapshot!.counts['savings_goals'], 1);

    final restoredDb = openMemoryDatabase();
    addTearDown(restoredDb.close);
    final restoredService = BackupService(restoredDb, storage);
    final outcome = await restoredService.restore(created);

    expect(outcome.snapshot.counts['transactions'], 3);
    expect(File(outcome.safetyBackup.path).existsSync(), isTrue);
    expect(outcome.safetyBackup.fileName, startsWith('pre-restore-'));

    final balances = await AccountRepository(restoredDb)
        .readBalances(until: FinancialDate.today());
    expect(balances.single.account.id, wallet);
    expect(balances.single.balance, 6000);

    final items = await PlanningRepository(restoredDb).readItems();
    expect(items.single.id, isNotEmpty);
    expect(items.single.paidTotal, 1000);
    expect(items.single.remaining, 2000);

    final debts = await DebtRepository(restoredDb).readDebts();
    expect(debts.single.paidTotal, 500);
    expect(debts.single.remaining, 1500);

    final goals = await SavingsGoalRepository(restoredDb).readAll();
    expect(goals.single.name, 'Emergência');
    expect(goals.single.currentAmount, 6000);

    final budgets = await BudgetRepository(restoredDb)
        .readMonth(DateTime.now());
    expect(budgets.single.limitAmount, 4000);
    expect(budgets.single.spent, 4000);

    final settings = await AppSettingsRepository(restoredDb).load();
    expect(settings.locale, 'pt_PT');
    expect(await restoredDb.readUserVersion(), 4);
  });

  test('backup inválido não altera os dados atuais', () async {
    await seedData();
    final before = await _countRows(db, 'transactions');

    final folder = await storage.directory();
    await File('${folder.path}${Platform.pathSeparator}corrompido.json')
        .writeAsString('{"format": "outra_coisa"}');

    final items = await service.listBackups();
    final invalid = items.firstWhere(
      (item) => item.file.fileName == 'corrompido.json',
    );
    expect(invalid.isValid, isFalse);
    expect(invalid.error, contains('não é um backup'));

    await expectLater(service.restore(invalid), throwsA(anything));
    expect(await _countRows(db, 'transactions'), before);
  });

  test('falha durante o restauro não deixa base parcial', () async {
    await seedData();
    final created = await service.createBackup(
      now: DateTime.utc(2026, 10, 30, 12, 0),
    );
    final contents = await storage.read(created.file);
    final decoded = BackupSnapshot.decode(contents);
    final tables = {
      for (final entry in decoded.tables.entries)
        entry.key: [
          for (final row in entry.value) Map<String, Object?>.from(row),
        ],
    };
    tables['transactions']!.first['amount'] = 0;
    final invalid = BackupSnapshot.create(
      createdAt: decoded.createdAt,
      settings: decoded.settings,
      tables: tables,
    );
    final stored = await storage.write(
      invalid.toJsonString(),
      prefix: 'invalido',
      now: DateTime.utc(2026, 10, 30, 12, 1),
    );
    final before = await _countRows(db, 'transactions');
    final balanceBefore = (await AccountRepository(
      db,
    ).readBalances(until: FinancialDate.today())).single.balance;

    await expectLater(
      service.restore(BackupListItem(file: stored, snapshot: invalid)),
      throwsA(anything),
    );

    expect(await _countRows(db, 'transactions'), before);
    final balanceAfter = (await AccountRepository(
      db,
    ).readBalances(until: FinancialDate.today())).single.balance;
    expect(balanceAfter, balanceBefore);
  });

  test('backup inclui configurações e um checksum válido', () async {
    await seedData();
    final created = await service.createBackup();
    final snapshot = created.snapshot!;
    expect(snapshot.currencyCode, 'XOF');
    expect(snapshot.locale, 'pt_PT');
    expect(snapshot.timeZone, 'Africa/Bissau');
    expect(snapshot.checksum, hasLength(8));
    expect(
      snapshot.tables['transactions']!.first['description'],
      contains(';'),
    );
  });

  test('importa um ficheiro externo com cópia de segurança prévia', () async {
    await seedData();
    final created = await service.createBackup(
      now: DateTime.utc(2026, 10, 30, 12, 0),
    );
    final contents = await storage.read(created.file);

    final targetDb = openMemoryDatabase();
    addTearDown(targetDb.close);
    final outcome = await BackupService(
      targetDb,
      storage,
    ).restoreExternal(contents);

    expect(outcome.snapshot.counts, created.snapshot!.counts);
    expect(File(outcome.safetyBackup.path).existsSync(), isTrue);
    expect(outcome.safetyBackup.fileName, startsWith('pre-restore-'));

    final items = await PlanningRepository(targetDb).readItems();
    expect(items.single.description, 'Renda');
    expect(items.single.paidTotal, 1000);
    final settings = await AppSettingsRepository(targetDb).load();
    expect(settings.currencyCode, 'XOF');
  });

  test('backup cifrado exige a frase-passe e restaura noutra base', () async {
    const passphrase = 'frase-segura-2026';
    await seedData();
    final created = await service.createBackup(
      passphrase: passphrase,
      now: DateTime.utc(2026, 10, 30, 12, 0),
    );
    expect(created.encrypted, isTrue);
    expect(created.isValid, isTrue);

    final contents = await storage.read(created.file);
    expect(isEncryptedBackup(contents), isTrue);
    expect(contents.contains('Mercado'), isFalse);

    final listed = (await service.listBackups()).firstWhere(
      (item) => item.file.fileName == created.file.fileName,
    );
    expect(listed.encrypted, isTrue);
    expect(listed.isValid, isFalse);

    await expectLater(service.restore(listed), throwsA(isA<AppFailure>()));
    await expectLater(
      service.restore(listed, passphrase: 'frase-errada-2026'),
      throwsA(
        isA<AppFailure>().having(
          (failure) => failure.message,
          'message',
          contains('Frase-passe incorreta'),
        ),
      ),
    );

    final restoredDb = openMemoryDatabase();
    addTearDown(restoredDb.close);
    final outcome = await BackupService(
      restoredDb,
      storage,
    ).restore(listed, passphrase: passphrase);
    expect(outcome.snapshot.counts['transactions'], 3);
    expect(File(outcome.safetyBackup.path).existsSync(), isTrue);

    final settings = await AppSettingsRepository(restoredDb).load();
    expect(settings.currencyCode, 'XOF');
    final balances = await AccountRepository(restoredDb)
        .readBalances(until: FinancialDate.today());
    expect(balances.single.balance, 6000);
  });

  test('backup cifrado importado restaura com a frase-passe', () async {
    const passphrase = 'frase-segura-2026';
    await seedData();
    final created = await service.createBackup(passphrase: passphrase);
    final contents = await storage.read(created.file);

    final targetDb = openMemoryDatabase();
    addTearDown(targetDb.close);
    final targetService = BackupService(targetDb, storage);

    await expectLater(
      targetService.restoreExternal(contents),
      throwsA(isA<AppFailure>()),
    );
    final outcome = await targetService.restoreExternal(
      contents,
      passphrase: passphrase,
    );
    expect(outcome.snapshot.counts['accounts'], 1);
    expect((await AppSettingsRepository(targetDb).load()).currencyCode, 'XOF');
  });

  test('ficheiro externo inválido não altera os dados atuais', () async {
    await seedData();
    final before = await _countRows(db, 'transactions');
    final balanceBefore = (await AccountRepository(
      db,
    ).readBalances(until: FinancialDate.today())).single.balance;

    await expectLater(
      service.restoreExternal('{"format": "outra_coisa"}'),
      throwsA(isA<AppFailure>()),
    );

    expect(await _countRows(db, 'transactions'), before);
    final balanceAfter = (await AccountRepository(
      db,
    ).readBalances(until: FinancialDate.today())).single.balance;
    expect(balanceAfter, balanceBefore);
  });
}

Future<int> _countRows(AppDatabase db, String table) async {
  final row = await db
      .customSelect('SELECT COUNT(*) AS total FROM "$table"')
      .getSingle();
  return row.read<int>('total');
}
