import 'package:financas_pessoais/features/reports/domain/report.dart';
import 'package:financas_pessoais/features/transactions/domain/movement.dart';
import 'package:flutter_test/flutter_test.dart';

MovementListItem item({
  String id = 'm1',
  MovementKind kind = MovementKind.expense,
  int amount = 1000,
  String account = 'Carteira',
  String? destination,
  String? category,
}) => MovementListItem(
  movement: Movement(
    id: id,
    kind: kind,
    accountId: 'acc-$account',
    destinationAccountId: destination == null ? null : 'acc-$destination',
    amount: amount,
    date: DateTime(2026, 10, 15),
  ),
  accountName: account,
  destinationAccountName: destination,
  categoryName: category,
);

void main() {
  test('soma rendimentos e despesas por categoria e conta', () {
    final summary = ReportSummary.of(
      [
        item(
          id: 'm1',
          kind: MovementKind.income,
          amount: 100000,
          account: 'Banco',
          category: 'Salário',
        ),
        item(
          id: 'm2',
          kind: MovementKind.expense,
          amount: 30000,
          account: 'Banco',
          category: 'Alimentação',
        ),
        item(
          id: 'm3',
          kind: MovementKind.transfer,
          amount: 20000,
          account: 'Banco',
          destination: 'Carteira',
        ),
      ],
      from: DateTime(2026, 10, 1),
      to: DateTime(2026, 10, 31),
    );

    expect(summary.income, 100000);
    expect(summary.expense, 30000);
    expect(summary.net, 70000);
    expect(summary.transferTotal, 20000);
    expect(summary.movementCount, 3);
    expect(summary.isEmpty, isFalse);

    expect(summary.categories.map((group) => group.label), [
      'Salário',
      'Alimentação',
    ]);
    expect(summary.categories.first.net, 100000);

    final bank = summary.accounts.firstWhere((group) => group.label == 'Banco');
    expect(bank.income, 100000);
    expect(bank.expense, 30000);
    expect(bank.transfersOut, 20000);
    expect(bank.transfersIn, 0);
    expect(bank.net, 70000);

    final wallet = summary.accounts.firstWhere(
      (group) => group.label == 'Carteira',
    );
    expect(wallet.transfersIn, 20000);
    expect(wallet.transfersOut, 0);
    expect(wallet.income, 0);
    expect(wallet.expense, 0);
    expect(wallet.net, 0);
  });

  test('transferências nunca entram no rendimento, despesa ou líquido', () {
    final summary = ReportSummary.of(
      [
        item(
          kind: MovementKind.transfer,
          amount: 5000,
          account: 'Banco',
          destination: 'Carteira',
        ),
      ],
      from: DateTime(2026, 10, 1),
      to: DateTime(2026, 10, 31),
    );

    expect(summary.income, 0);
    expect(summary.expense, 0);
    expect(summary.net, 0);
    expect(summary.transferTotal, 5000);
    expect(
      summary.categories,
      isEmpty,
      reason: 'transferências não pertencem a nenhuma categoria do relatório',
    );
    expect(summary.accounts.first.label, 'Banco');
    expect(summary.accounts.last.transfersIn, 5000);
  });

  test('sem movimentos o resumo fica vazio e sem grupos', () {
    final summary = ReportSummary.of(
      const [],
      from: DateTime(2026, 10, 1),
      to: DateTime(2026, 10, 31),
    );

    expect(summary.isEmpty, isTrue);
    expect(summary.categories, isEmpty);
    expect(summary.accounts, isEmpty);
    expect(summary.net, 0);
  });
}
