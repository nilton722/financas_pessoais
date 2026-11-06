import 'dart:io';

import 'package:financas_pessoais/core/files/app_files.dart';
import 'package:financas_pessoais/core/formatters/date_formatter.dart';
import 'package:financas_pessoais/core/formatters/money_formatter.dart';
import 'package:financas_pessoais/features/reports/data/report_csv.dart';
import 'package:financas_pessoais/features/reports/presentation/reports_providers.dart';
import 'package:financas_pessoais/features/transactions/data/transaction_repository.dart';
import 'package:financas_pessoais/features/transactions/domain/movement.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/database_fixtures.dart';
import '../support/domain_fixtures.dart';
import '../support/widget_harness.dart';

void main() {
  Directory createRoot() {
    final root = Directory.systemTemp.createTempSync('relatorios-widget');
    addTearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });
    return root;
  }

  testWidgets('relatório mostra resumo, grupos e exporta CSV', (tester) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    final root = createRoot();
    final wallet = await createTestAccount(
      db,
      name: 'Carteira',
      openingBalance: 50000,
    );
    final repository = TransactionRepository(db);
    await repository.createMovement(
      MovementDraft(
        kind: MovementKind.income,
        amount: 100000,
        date: FinancialDate.today(),
        accountId: wallet,
        categoryId: seededSalaryCategoryId,
        description: 'Salário de outubro',
      ),
    );
    await repository.createMovement(
      MovementDraft(
        kind: MovementKind.expense,
        amount: 12000,
        date: FinancialDate.today(),
        accountId: wallet,
        categoryId: seededFoodCategoryId,
        description: 'Mercado',
      ),
    );

    await pumpApp(tester, db, filesRoot: () async => root);

    await tapVisible(tester, find.byKey(const Key('dashboard-reports')));
    expect(find.widgetWithText(AppBar, 'Relatórios'), findsOneWidget);
    expect(find.byKey(const Key('report-summary')), findsOneWidget);
    expect(find.text('Salário'), findsOneWidget);
    expect(find.text('Alimentação'), findsOneWidget);
    expect(find.textContaining('2 movimentos'), findsOneWidget);
    expect(
      find.textContaining(MoneyFormatter.formatXof(88000)),
      findsWidgets,
      reason: 'resultado do período (100 000 − 12 000)',
    );

    // A exportação escreve em disco; alterna tempo real e simulado até
    // o trabalho concluir.
    await tapVisible(tester, find.byKey(const Key('report-export')));
    await pumpDisk(tester, find.textContaining('Relatório exportado'));
    expect(find.textContaining('Relatório exportado'), findsOneWidget);

    final exports = Directory(
      '${root.path}${Platform.pathSeparator}${AppFiles.exportsFolder}',
    ).listSync().whereType<File>().toList();
    expect(exports, hasLength(1));
    final csv = exports.single.readAsStringSync();
    expect(csv, contains('Salário de outubro'));
    expect(csv, contains('Mercado'));
    expect(
      csv,
      contains(
        FinancialDate.toDisplay(
          FinancialDate.fromDateTime(FinancialDate.today()),
        ),
      ),
    );

    await disposeApp(tester);
  });

  testWidgets('guarda o CSV no destino escolhido pelo sistema', (tester) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    final root = createRoot();
    final wallet = await createTestAccount(
      db,
      name: 'Carteira',
      openingBalance: 50000,
    );
    final repository = TransactionRepository(db);
    await repository.createMovement(
      MovementDraft(
        kind: MovementKind.income,
        amount: 100000,
        date: FinancialDate.today(),
        accountId: wallet,
        categoryId: seededSalaryCategoryId,
        description: 'Salário de outubro',
      ),
    );
    String? savedName;
    String? savedContents;

    await pumpApp(
      tester,
      db,
      filesRoot: () async => root,
      overrides: [
        reportFileSaverProvider.overrideWithValue(({
          required String fileName,
          required String contents,
        }) async {
          savedName = fileName;
          savedContents = contents;
          return true;
        }),
      ],
    );

    await tapVisible(tester, find.byKey(const Key('dashboard-reports')));
    await tester.tap(find.byKey(const Key('report-save-to')));
    await pumpDisk(tester, find.textContaining('Relatório guardado'));

    expect(savedName, startsWith('relatorio-'));
    expect(savedName, endsWith('.csv'));
    expect(savedContents, startsWith(ReportCsv.bom));
    expect(savedContents, contains('Salário de outubro'));
    expect(find.textContaining('Relatório guardado'), findsOneWidget);

    final exports = Directory(
      '${root.path}${Platform.pathSeparator}${AppFiles.exportsFolder}',
    ).listSync().whereType<File>().toList();
    expect(exports, hasLength(1));

    await disposeApp(tester);
  });

  testWidgets('cancelar a gravação do CSV mantém a cópia local', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    final root = createRoot();
    final wallet = await createTestAccount(
      db,
      name: 'Carteira',
      openingBalance: 50000,
    );
    final repository = TransactionRepository(db);
    await repository.createMovement(
      MovementDraft(
        kind: MovementKind.expense,
        amount: 12000,
        date: FinancialDate.today(),
        accountId: wallet,
        categoryId: seededFoodCategoryId,
        description: 'Mercado',
      ),
    );

    await pumpApp(
      tester,
      db,
      filesRoot: () async => root,
      overrides: [
        reportFileSaverProvider.overrideWithValue(
          ({required String fileName, required String contents}) async => false,
        ),
      ],
    );

    await tapVisible(tester, find.byKey(const Key('dashboard-reports')));
    await tester.tap(find.byKey(const Key('report-save-to')));
    await pumpDisk(tester, find.textContaining('não foi guardado fora'));

    final exports = Directory(
      '${root.path}${Platform.pathSeparator}${AppFiles.exportsFolder}',
    ).listSync().whereType<File>().toList();
    expect(exports, hasLength(1));

    await disposeApp(tester);
  });

  testWidgets('período sem movimentos desativa a exportação', (tester) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);

    await pumpApp(tester, db);
    await tapVisible(tester, find.byKey(const Key('dashboard-reports')));

    expect(find.text('Sem movimentos no período'), findsOneWidget);
    expect(
      find.byKey(const Key('report-export')),
      findsNothing,
      reason: 'sem dados a exportação nem sequer é oferecida',
    );
    expect(find.textContaining('Não há movimentos'), findsNothing);

    await tapVisible(tester, find.text('Este mês'));
    await tapVisible(tester, find.text('Mês anterior').last);

    expect(find.text('Sem movimentos no período'), findsOneWidget);
    expect(find.byKey(const Key('report-export')), findsNothing);

    await disposeApp(tester);
  });

  testWidgets('definições explicam privacidade, dados e backup', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    final root = createRoot();

    await pumpApp(tester, db, filesRoot: () async => root);

    await tapVisible(tester, find.byKey(const Key('dashboard-settings')));
    expect(find.widgetWithText(AppBar, 'Definições'), findsOneWidget);
    expect(find.byKey(const Key('settings-privacy')), findsOneWidget);
    expect(find.textContaining('não se liga à internet'), findsOneWidget);
    expect(find.textContaining('não são cifradas'), findsOneWidget);
    expect(find.textContaining('cifrados com frase-passe'), findsOneWidget);
    expect(find.textContaining('barreira de interface'), findsOneWidget);
    expect(find.text('Onde estão os dados'), findsOneWidget);
    expect(find.text('Backup e restauração'), findsOneWidget);
    expect(find.text('Relatórios e exportação'), findsOneWidget);

    await scrollToVisible(tester, find.byKey(const Key('settings-backups')));
    await tester.tap(find.byKey(const Key('settings-backups')));
    await pumpDisk(tester, find.text('Ainda sem backups'));
    expect(find.widgetWithText(AppBar, 'Backup e restauração'), findsOneWidget);
    expect(find.text('Ainda sem backups'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('definições apresentam a marca e o slogan no Sobre', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    final root = createRoot();

    await pumpApp(tester, db, filesRoot: () async => root);
    await tapVisible(tester, find.byKey(const Key('dashboard-settings')));

    await tester.scrollUntilVisible(
      find.byKey(const Key('settings-about')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('settings-brand-logo')), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.semanticLabel ==
                'Nô Dinheru — O teu dinheiro, sob controlo.',
      ),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.textContaining('Nô Dinheru 1.0.0'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Nô Dinheru 1.0.0'), findsOneWidget);

    await disposeApp(tester);
  });
}
