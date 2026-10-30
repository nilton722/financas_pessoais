import 'dart:io';

import 'package:financas_pessoais/core/formatters/date_formatter.dart';
import 'package:financas_pessoais/core/formatters/money_formatter.dart';
import 'package:financas_pessoais/features/accounts/data/account_repository.dart';
import 'package:financas_pessoais/features/accounts/domain/account_balance.dart';
import 'package:financas_pessoais/features/forecast/data/forecast_repository.dart';
import 'package:financas_pessoais/features/planning/data/budget_repository.dart';
import 'package:financas_pessoais/features/planning/data/planning_repository.dart';
import 'package:financas_pessoais/features/transactions/data/transaction_repository.dart';
import 'package:financas_pessoais/features/transactions/domain/movement.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/database_fixtures.dart';
import '../support/domain_fixtures.dart';
import '../support/widget_harness.dart';

/// Validação da Fase 06: uma única jornada cobre primeira abertura, contas,
/// rendimento/despesa, transferência, orçamento, compromisso pago, previsão e
/// ciclo completo de backup/restauro. Os valores verificados no fim são lidos
/// da base restaurada, não da interface.
void main() {
  testWidgets('jornada completa offline e restauro preservam a integridade', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);

    final filesRoot = Directory.systemTemp.createTempSync('release-flow');
    addTearDown(() {
      if (filesRoot.existsSync()) {
        filesRoot.deleteSync(recursive: true);
      }
    });

    await pumpApp(tester, db, filesRoot: () async => filesRoot);
    expect(find.text('Ainda sem contas'), findsOneWidget);

    // Contas: Carteira com 10.000 e Poupança sem saldo inicial.
    await tapNavigation(tester, 'Contas');
    await _createAccount(tester, 'Carteira', '10000');
    await _createAccount(tester, 'Poupança', '0');
    expect(find.text('Carteira'), findsOneWidget);
    expect(find.text('Poupança'), findsOneWidget);

    // Movimentos: rendimento, despesa e transferência entre contas próprias.
    await tapNavigation(tester, 'Movimentos');
    await _createMovement(
      tester,
      kind: 'Rendimento',
      amount: '50000',
      account: 'Carteira',
      category: 'Salário',
    );
    await _createMovement(
      tester,
      kind: 'Despesa',
      amount: '12000',
      account: 'Carteira',
      category: 'Alimentação',
    );
    await _createMovement(
      tester,
      kind: 'Transferência',
      amount: '5000',
      account: 'Carteira',
      destination: 'Poupança',
    );
    expect(find.text('Salário'), findsOneWidget);
    expect(find.text('Transferência'), findsWidgets);

    // Orçamento mensal de 20.000 para Alimentação: o gasto vem da despesa real.
    await tapNavigation(tester, 'Plano');
    await tapVisible(tester, find.text('Orçamentos'));
    await tapVisible(
      tester,
      find.widgetWithText(FloatingActionButton, 'Novo orçamento'),
    );
    await tapVisible(tester, _dropdown('Categoria de despesa'));
    await tapVisible(tester, find.text('Alimentação').last);
    await tester.enterText(find.byType(TextField).first, '20000');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Guardar'));
    expect(find.text('Orçamento guardado.'), findsOneWidget);
    await _dismissSnackBar(tester);
    expect(find.text('Gasto'), findsOneWidget);
    expect(find.text(MoneyFormatter.formatXof(12000)), findsWidgets);
    expect(find.text(MoneyFormatter.formatXof(20000)), findsWidgets);
    expect(find.text('60%'), findsOneWidget);

    // Compromisso de 8.000 pago por inteiro: cria um único movimento real.
    await _goBack(tester);
    await settle(tester);
    await tapVisible(tester, find.text('Compromissos'));
    await tapVisible(
      tester,
      find.widgetWithText(FloatingActionButton, 'Novo compromisso'),
    );
    await tester.enterText(find.byType(TextField).first, '8000');
    await tester.enterText(find.byType(TextField).at(1), 'Renda');
    await tapVisible(tester, _dropdown('Conta (opcional)'));
    await tapVisible(tester, find.text('Carteira').last);
    await tapVisible(tester, _dropdown('Categoria (opcional)'));
    await tapVisible(tester, find.text('Habitação').last);
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Guardar'));
    expect(find.text('Compromisso criado.'), findsOneWidget);
    await _dismissSnackBar(tester);

    await tapVisible(tester, find.byTooltip('Opções'));
    await tapVisible(tester, find.text('Pagar'));
    await tapVisible(
      tester,
      find.widgetWithText(FilledButton, 'Registar pagamento'),
    );
    expect(find.text('Pagamento registado.'), findsOneWidget);
    expect(find.text('Sem compromissos pendentes'), findsOneWidget);
    await _dismissSnackBar(tester);

    // Painel: 10.000 + 50.000 - 12.000 - 8.000 = 40.000; a transferência
    // apenas move dinheiro entre contas próprias.
    await _goBack(tester);
    await settle(tester);
    await tapNavigation(tester, 'Painel');
    expect(
      find.text(MoneyFormatter.formatXof(40000)),
      findsWidgets,
      reason: 'saldo real consolidado após todas as operações',
    );

    await tapVisible(tester, find.text('Previsão (30 dias)'));
    expect(find.widgetWithText(AppBar, 'Previsão'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('forecastClosingBalance'))).data,
      MoneyFormatter.formatXof(40000),
    );
    expect(find.text('Sem compromissos'), findsOneWidget);
    await _goBack(tester);
    await settle(tester);

    // Backup criado depois de todos os dados; um movimento posterior tem de
    // desaparecer no restauro.
    await tapVisible(tester, find.byKey(const Key('dashboard-settings')));
    await tester.tap(find.byKey(const Key('settings-backups')));
    await pumpDisk(tester, find.text('Ainda sem backups'));
    await tester.tap(find.byKey(const Key('backup-create')));
    await pumpDisk(tester, find.textContaining('Backup criado'));
    await _dismissSnackBar(tester);
    await pumpDisk(tester, find.byKey(const Key('backup-list')));

    final accounts = await tester.runAsync(
      () => AccountRepository(db).readBalances(until: FinancialDate.today()),
    );
    final wallet = accounts!.singleWhere(
      (entry) => entry.account.name == 'Carteira',
    );
    await tester.runAsync(
      () => TransactionRepository(db).createMovement(
        MovementDraft(
          kind: MovementKind.expense,
          amount: 7000,
          date: FinancialDate.today(),
          accountId: wallet.account.id,
          categoryId: seededFoodCategoryId,
          description: 'Compra posterior ao backup',
        ),
      ),
    );
    await settle(tester);

    await tapVisible(
      tester,
      find.descendant(
        of: find.byKey(const Key('backup-list')),
        matching: find.byType(ListTile),
      ),
    );
    expect(find.textContaining('Integridade verificada'), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('backup-restore')));
    await tester.tap(find.byKey(const Key('backup-confirm-restore')));
    await pumpDisk(tester, find.text('Backup restaurado'));
    await tester.tap(find.widgetWithText(FilledButton, 'Concluir'));
    await pumpDisk(
      tester,
      find.descendant(
        of: find.byKey(const Key('backup-list')),
        matching: find.textContaining('pre-restore'),
      ),
    );

    await disposeApp(tester);

    final restoredBalances = await AccountRepository(db)
        .readBalances(until: FinancialDate.today());
    expect(consolidatedBalance(restoredBalances), 40000);
    expect(
      restoredBalances
          .singleWhere((entry) => entry.account.name == 'Carteira')
          .balance,
      35000,
    );
    expect(
      restoredBalances
          .singleWhere((entry) => entry.account.name == 'Poupança')
          .balance,
      5000,
    );

    final movements = await TransactionRepository(db)
        .readMovements(const MovementFilter());
    expect(
      movements,
      hasLength(4),
      reason:
          'rendimento, despesa, transferência e pagamento do compromisso; '
          'o movimento posterior ao backup tem de desaparecer',
    );
    expect(
      movements.where(
        (item) => item.movement.description?.contains('posterior') ?? false,
      ),
      isEmpty,
    );

    final budgets = await BudgetRepository(db).readMonth(FinancialDate.today());
    expect(budgets.single.limitAmount, 20000);
    expect(budgets.single.spent, 12000);

    final items = await PlanningRepository(db).readItems();
    expect(items.single.paidTotal, 8000);
    expect(items.single.remaining, 0);

    final forecast = await ForecastRepository(db)
        .buildBundle(cutoff: FinancialDate.today());
    expect(forecast.results[30]!.closingBalance, 40000);
    expect(forecast.results[30]!.hasNegativeBalance, isFalse);
  });
}

Future<void> _createAccount(
  WidgetTester tester,
  String name,
  String openingBalance,
) async {
  await tapVisible(
    tester,
    find.widgetWithText(FloatingActionButton, 'Nova conta'),
  );
  await tester.enterText(find.byType(TextField).first, name);
  await tester.enterText(find.byType(TextField).at(1), openingBalance);
  await tapVisible(tester, find.widgetWithText(FilledButton, 'Guardar'));
  expect(find.text('Conta criada.'), findsOneWidget);
  await _dismissSnackBar(tester);
}

Future<void> _createMovement(
  WidgetTester tester, {
  required String kind,
  required String amount,
  required String account,
  String? destination,
  String? category,
}) async {
  await tapVisible(
    tester,
    find.widgetWithText(FloatingActionButton, 'Novo movimento'),
  );
  if (kind != 'Rendimento') {
    await tapVisible(tester, find.widgetWithText(ChoiceChip, kind));
  }
  await tester.enterText(find.byType(TextField).first, amount);
  await tapVisible(
    tester,
    _dropdown(destination == null ? 'Conta' : 'Conta de origem'),
  );
  await tapVisible(tester, find.text(account).last);
  if (destination != null) {
    await tapVisible(tester, _dropdown('Conta de destino'));
    await tapVisible(tester, find.text(destination).last);
  } else {
    await tapVisible(tester, _dropdown('Categoria'));
    await tapVisible(tester, find.text(category!).last);
  }
  await tapVisible(tester, find.widgetWithText(FilledButton, 'Guardar'));
  expect(find.text('Movimento registado.'), findsOneWidget);
  await _dismissSnackBar(tester);
}

/// Deixa o SnackBar expirar para não interceptar toques seguintes.
Future<void> _dismissSnackBar(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await settle(tester);
}

/// Volta atrás por uma rota empilhada. `pageBack` depende do tooltip localizado
/// (“Back” em inglês), que não existe com a interface em português.
Future<void> _goBack(WidgetTester tester) async {
  await tapVisible(tester, find.byType(BackButton));
}

/// Localiza o dropdown pela etiqueta visível, em vez de depender da ordem dos
/// campos no formulário.
Finder _dropdown(String label) => find.descendant(
  of: find.widgetWithText(InputDecorator, label),
  matching: find.byType(DropdownButton<String>),
);
