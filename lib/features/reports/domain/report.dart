import '../../transactions/domain/movement.dart';

enum ReportGroupMode {
  category('Categoria'),
  account('Conta');

  const ReportGroupMode(this.label);

  final String label;
}

class ReportGroup {
  const ReportGroup({
    required this.label,
    required this.income,
    required this.expense,
    required this.transfersIn,
    required this.transfersOut,
  });

  final String label;
  final int income;
  final int expense;
  final int transfersIn;
  final int transfersOut;

  int get net => income - expense;

  int get volume => income + expense;

  int get transfers => transfersIn + transfersOut;
}

/// Resumo de um período. Transferências não são rendimento nem despesa; são
/// contabilizadas à parte e nunca entram no líquido.
class ReportSummary {
  const ReportSummary({
    required this.from,
    required this.to,
    required this.income,
    required this.expense,
    required this.transferTotal,
    required this.movementCount,
    required this.categories,
    required this.accounts,
  });

  final DateTime from;
  final DateTime to;
  final int income;
  final int expense;
  final int transferTotal;
  final int movementCount;
  final List<ReportGroup> categories;
  final List<ReportGroup> accounts;

  int get net => income - expense;

  bool get isEmpty => movementCount == 0;

  factory ReportSummary.of(
    List<MovementListItem> items, {
    required DateTime from,
    required DateTime to,
  }) {
    var income = 0;
    var expense = 0;
    var transferTotal = 0;
    final categories = <String, _GroupBuilder>{};
    final accounts = <String, _GroupBuilder>{};

    _GroupBuilder group(Map<String, _GroupBuilder> groups, String label) =>
        groups.putIfAbsent(label, _GroupBuilder.new);

    for (final item in items) {
      final movement = item.movement;
      final account = group(accounts, item.accountName);

      switch (movement.kind) {
        case MovementKind.income:
          income += movement.amount;
          account.income += movement.amount;
          group(categories, item.categoryName ?? 'Sem categoria').income +=
              movement.amount;
        case MovementKind.expense:
          expense += movement.amount;
          account.expense += movement.amount;
          group(categories, item.categoryName ?? 'Sem categoria').expense +=
              movement.amount;
        case MovementKind.transfer:
          // Uma transferência mexe em duas contas, mas em nenhuma categoria:
          // não é rendimento nem despesa.
          transferTotal += movement.amount;
          account.transfersOut += movement.amount;
          final destination = item.destinationAccountName;
          if (destination != null && destination.isNotEmpty) {
            group(accounts, destination).transfersIn += movement.amount;
          }
      }
    }

    return ReportSummary(
      from: from,
      to: to,
      income: income,
      expense: expense,
      transferTotal: transferTotal,
      movementCount: items.length,
      categories: _sortedGroups(categories),
      accounts: _sortedGroups(accounts),
    );
  }
}

List<ReportGroup> _sortedGroups(Map<String, _GroupBuilder> groups) {
  final result = [
    for (final entry in groups.entries)
      ReportGroup(
        label: entry.key,
        income: entry.value.income,
        expense: entry.value.expense,
        transfersIn: entry.value.transfersIn,
        transfersOut: entry.value.transfersOut,
      ),
  ];
  result.sort((a, b) {
    final volume = b.volume.compareTo(a.volume);
    if (volume != 0) {
      return volume;
    }
    return a.label.toLowerCase().compareTo(b.label.toLowerCase());
  });
  return List<ReportGroup>.unmodifiable(result);
}

class _GroupBuilder {
  int income = 0;
  int expense = 0;
  int transfersIn = 0;
  int transfersOut = 0;
}
