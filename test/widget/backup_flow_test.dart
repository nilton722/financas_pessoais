import 'dart:convert';
import 'dart:io';

import 'package:financas_pessoais/core/backup/backup_format.dart';
import 'package:financas_pessoais/core/backup/backup_service.dart';
import 'package:financas_pessoais/core/backup/backup_storage.dart';
import 'package:financas_pessoais/core/files/app_files.dart';
import 'package:financas_pessoais/core/formatters/date_formatter.dart';
import 'package:financas_pessoais/features/settings/data/backup_file_picker.dart';
import 'package:financas_pessoais/features/settings/presentation/backup_providers.dart';
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

  /// JSON de um backup criado noutra instalação, com uma conta diferente.
  Future<String> externalBackup(Directory root) async {
    final sourceDb = openMemoryDatabase();
    addTearDown(sourceDb.close);
    await createTestAccount(sourceDb, name: 'Importada', openingBalance: 42000);
    final created = await BackupService(
      sourceDb,
      BackupStorage(AppFiles(rootResolver: () async => root)),
    ).createBackup();
    return created.snapshot!.toJsonString();
  }

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
    await scrollToVisible(tester, find.byKey(const Key('settings-backups')));
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
    await scrollToVisible(tester, find.byKey(const Key('settings-backups')));
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

  testWidgets('guarda uma cópia no destino escolhido pelo sistema', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    final root = createRoot();
    await createTestAccount(db, name: 'Carteira', openingBalance: 10000);
    String? savedName;
    String? savedContents;

    await pumpApp(
      tester,
      db,
      filesRoot: () async => root,
      overrides: [
        backupFileSaverProvider.overrideWithValue(({
          required String fileName,
          required String contents,
        }) async {
          savedName = fileName;
          savedContents = contents;
          return true;
        }),
      ],
    );

    await tapVisible(tester, find.byKey(const Key('dashboard-settings')));
    await scrollToVisible(tester, find.byKey(const Key('settings-backups')));
    await tester.tap(find.byKey(const Key('settings-backups')));
    await pumpDisk(tester, find.text('Ainda sem backups'));

    await tester.tap(find.byKey(const Key('backup-save-to')));
    await pumpDisk(tester, find.textContaining('Backup guardado'));

    expect(savedName, startsWith('backup-'));
    final snapshot = BackupSnapshot.decode(savedContents!);
    expect(snapshot.totalRows, greaterThan(0));
    expect(find.textContaining('Backup guardado'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await pumpDisk(tester, find.byKey(const Key('backup-list')));
    expect(find.byKey(const Key('backup-list')), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('cancelar a gravação externa mantém a cópia local', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    final root = createRoot();
    await createTestAccount(db, name: 'Carteira', openingBalance: 10000);

    await pumpApp(
      tester,
      db,
      filesRoot: () async => root,
      overrides: [
        backupFileSaverProvider.overrideWithValue(
          ({required String fileName, required String contents}) async => false,
        ),
      ],
    );

    await tapVisible(tester, find.byKey(const Key('dashboard-settings')));
    await scrollToVisible(tester, find.byKey(const Key('settings-backups')));
    await tester.tap(find.byKey(const Key('settings-backups')));
    await pumpDisk(tester, find.text('Ainda sem backups'));

    await tester.tap(find.byKey(const Key('backup-save-to')));
    await pumpDisk(tester, find.textContaining('não foi guardado fora'));

    final files = backupsFolder(root)
        .listSync()
        .whereType<File>()
        .where((file) => file.uri.pathSegments.last.startsWith('backup-'));
    expect(files, hasLength(1));

    await disposeApp(tester);
  });

  Future<void> runImportFlow(WidgetTester tester, {Size? size}) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    final root = createRoot();
    await createTestAccount(db, name: 'Carteira', openingBalance: 10000);
    final contents = (await tester.runAsync(
      () => externalBackup(createRoot()),
    ))!;

    await pumpApp(
      tester,
      db,
      filesRoot: () async => root,
      size: size ?? const Size(800, 1600),
      overrides: [
        backupFilePickerProvider.overrideWithValue(
          () async => PickedBackup(
            fileName: 'noutro-telefone.json',
            contents: contents,
          ),
        ),
      ],
    );

    await tapVisible(tester, find.byKey(const Key('dashboard-settings')));
    await scrollToVisible(tester, find.byKey(const Key('settings-backups')));
    await tester.tap(find.byKey(const Key('settings-backups')));
    await pumpDisk(tester, find.text('Ainda sem backups'));
    expect(find.byKey(const Key('backup-import')), findsOneWidget);

    await tapVisible(tester, find.byKey(const Key('backup-import')));
    await pumpDisk(tester, find.text('noutro-telefone.json'));
    expect(find.textContaining('Ficheiro importado'), findsOneWidget);
    expect(find.textContaining('Integridade verificada'), findsOneWidget);

    await tapVisible(tester, find.byKey(const Key('backup-restore')));
    expect(find.text('Restaurar este backup?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('backup-confirm-restore')));
    await pumpDisk(tester, find.text('Backup restaurado'));
    expect(find.textContaining('pre-restore'), findsWidgets);

    await tester.tap(find.widgetWithText(FilledButton, 'Concluir'));
    await pumpDisk(
      tester,
      find.descendant(
        of: find.byKey(const Key('backup-list')),
        matching: find.textContaining('pre-restore'),
      ),
    );

    final rows = await tester.runAsync(
      () => db.customSelect('SELECT name, opening_balance FROM accounts').get(),
    );
    expect(rows, hasLength(1));
    expect(rows!.single.read<String>('name'), 'Importada');
    expect(rows.single.read<int>('opening_balance'), 42000);

    await disposeApp(tester);
  }

  testWidgets('importa um backup de um ficheiro externo', (tester) async {
    await runImportFlow(tester);
  });

  testWidgets('importação em ecrã de telemóvel não transborda', (tester) async {
    await runImportFlow(tester, size: const Size(411, 891));
  });

  testWidgets('importar ficheiro inválido não altera os dados', (tester) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    final root = createRoot();
    await createTestAccount(db, name: 'Carteira', openingBalance: 10000);

    await pumpApp(
      tester,
      db,
      filesRoot: () async => root,
      overrides: [
        backupFilePickerProvider.overrideWithValue(
          () async => const PickedBackup(
            fileName: 'mau.json',
            contents: '{"format": "outra_coisa"}',
          ),
        ),
      ],
    );

    await tapVisible(tester, find.byKey(const Key('dashboard-settings')));
    await scrollToVisible(tester, find.byKey(const Key('settings-backups')));
    await tester.tap(find.byKey(const Key('settings-backups')));
    await pumpDisk(tester, find.text('Ainda sem backups'));

    await tapVisible(tester, find.byKey(const Key('backup-import')));
    await pumpDisk(
      tester,
      find.textContaining('não é um backup desta aplicação'),
    );
    expect(
      find.textContaining('não é um backup desta aplicação'),
      findsOneWidget,
    );

    final rows = await tester.runAsync(
      () => db.customSelect('SELECT name FROM accounts').get(),
    );
    expect(rows, hasLength(1));
    expect(rows!.single.read<String>('name'), 'Carteira');

    await disposeApp(tester);
  });
}
