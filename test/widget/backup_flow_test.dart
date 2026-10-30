import 'dart:convert';
import 'dart:io';

import 'package:financas_pessoais/core/backup/backup_format.dart';
import 'package:financas_pessoais/core/files/app_files.dart';
import 'package:financas_pessoais/core/formatters/date_formatter.dart';
import 'package:financas_pessoais/features/transactions/data/transaction_repository.dart';
import 'package:financas_pessoais/features/transactions/domain/movement.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/database_fixtures.dart';
import '../support/domain_fixtures.dart';
import '../support/widget_harness.dart';

void main() {
  Directory createRoot() {
    final root = Directory.systemTemp.createTempSync('backup-widget');
    addTearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });
    return root;
  }

  Directory backupsFolder(Directory root) => Directory(
    '${root.path}${Platform.pathSeparator}${AppFiles.backupsFolder}',
  );

  testWidgets('cria backup, restaura e preserva a base anterior', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    final root = createRoot();
    final wallet = await createTestAccount(
      db,
      name: 'Carteira',
      openingBalance: 10000,
    );
    await pumpApp(tester, db, filesRoot: () async => root);

    await tapVisible(tester, find.byKey(const Key('dashboard-settings')));
    await tester.tap(find.byKey(const Key('settings-backups')));
    await pumpDisk(tester, find.text('Ainda sem backups'));
    expect(find.text('Ainda sem backups'), findsOneWidget);

    await tester.tap(find.byKey(const Key('backup-create')));
    await pumpDisk(tester, find.textContaining('Backup criado'));
    expect(find.textContaining('Backup criado'), findsOneWidget);

    // Espera o SnackBar desaparecer e a lista recarregar do disco.
    await tester.pump(const Duration(seconds: 5));
    await settle(tester);
    await pumpDisk(tester, find.byKey(const Key('backup-list')));
    expect(find.byKey(const Key('backup-list')), findsOneWidget);

    // Um movimento posterior ao backup deve desaparecer no restauro.
    final repository = TransactionRepository(db);
    await tester.runAsync(
      () => repository.createMovement(
        MovementDraft(
          kind: MovementKind.expense,
          amount: 2500,
          date: FinancialDate.today(),
          accountId: wallet,
          categoryId: seededFoodCategoryId,
          description: 'Compra posterior',
        ),
      ),
    );
    expect(
      await tester.runAsync(
        () => repository.readMovements(const MovementFilter()),
      ),
      hasLength(1),
    );

    await tapVisible(
      tester,
      find.descendant(
        of: find.byKey(const Key('backup-list')),
        matching: find.byType(ListTile),
      ),
    );
    expect(find.text('Conteúdo'), findsOneWidget);
    expect(find.textContaining('Integridade verificada'), findsOneWidget);

    await tapVisible(tester, find.byKey(const Key('backup-restore')));
    expect(find.text('Restaurar este backup?'), findsOneWidget);
    expect(find.textContaining('cópia de segurança'), findsOneWidget);

    await tester.tap(find.byKey(const Key('backup-confirm-restore')));
    await pumpDisk(tester, find.text('Backup restaurado'));
    expect(find.text('Backup restaurado'), findsOneWidget);
    expect(find.textContaining('pre-restore'), findsWidgets);

    await tester.tap(find.widgetWithText(FilledButton, 'Concluir'));
    await pumpDisk(
      tester,
      find.descendant(
        of: find.byKey(const Key('backup-list')),
        matching: find.textContaining('pre-restore'),
      ),
    );
    expect(find.textContaining('pre-restore'), findsWidgets);

    expect(
      await tester.runAsync(
        () => repository.readMovements(const MovementFilter()),
      ),
      isEmpty,
      reason: 'o restauro substitui os movimentos pelo estado do backup',
    );
    final accounts = await tester.runAsync(
      () =>
          db.customSelect('SELECT COUNT(*) AS total FROM accounts').getSingle(),
    );
    expect(accounts!.read<int>('total'), 1);

    final backupFiles = backupsFolder(root)
        .listSync()
        .whereType<File>()
        .map((file) => file.uri.pathSegments.last);
    expect(backupFiles.any((name) => name.startsWith('pre-restore-')), isTrue);

    await disposeApp(tester);
  });

  testWidgets('backup corrompido e versão futura não são restauráveis', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    final root = createRoot();
    final backups = backupsFolder(root)..createSync(recursive: true);

    File('${backups.path}${Platform.pathSeparator}mau.json')
        .writeAsStringSync('{ isto não é json');
    final snapshot = BackupSnapshot.create(
      createdAt: DateTime.utc(2026, 10, 1),
      settings: const {
        'currency_code': 'XOF',
        'locale': 'pt_PT',
        'time_zone': 'Africa/Bissau',
      },
      tables: {for (final table in backupTableNames) table: const []},
    );
    final document =
        jsonDecode(snapshot.toJsonString()) as Map<String, dynamic>;
    document['schemaVersion'] = backupSchemaVersion + 1;
    File('${backups.path}${Platform.pathSeparator}futuro.json')
        .writeAsStringSync(jsonEncode(document));

    await pumpApp(tester, db, filesRoot: () async => root);

    await tapVisible(tester, find.byKey(const Key('dashboard-settings')));
    await tester.tap(find.byKey(const Key('settings-backups')));
    await pumpDisk(tester, find.byKey(const Key('backup-list')));
    expect(find.textContaining('não é um backup JSON válido'), findsWidgets);
    expect(find.textContaining('esquema v5'), findsWidgets);

    await tapVisible(tester, find.text('mau.json'));
    expect(find.textContaining('não pode ser restaurado'), findsOneWidget);
    expect(find.byKey(const Key('backup-restore')), findsNothing);
    await tapVisible(tester, find.text('Fechar'));

    await tapVisible(tester, find.text('futuro.json'));
    expect(find.textContaining('esquema v5'), findsWidgets);
    expect(find.byKey(const Key('backup-restore')), findsNothing);

    await disposeApp(tester);
  });
}
