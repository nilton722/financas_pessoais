import '../../../core/formatters/date_formatter.dart';
import '../../../core/formatters/money_input_parser.dart';

enum MovementKind {
  income('income', 'Rendimento'),
  expense('expense', 'Despesa'),
  transfer('transfer', 'Transferência');

  const MovementKind(this.dbValue, this.label);

  final String dbValue;
  final String label;

  bool get isTransfer => this == MovementKind.transfer;

  static MovementKind fromDb(String value) => values.firstWhere(
    (kind) => kind.dbValue == value,
    orElse: () => MovementKind.expense,
  );
}

class Movement {
  const Movement({
    required this.id,
    required this.kind,
    required this.accountId,
    required this.amount,
    required this.date,
    this.destinationAccountId,
    this.categoryId,
    this.description,
    this.notes,
    this.deletedAt,
  });

  final String id;
  final MovementKind kind;
  final String accountId;
  final String? destinationAccountId;
  final String? categoryId;
  final int amount;
  final DateTime date;
  final String? description;
  final String? notes;
  final DateTime? deletedAt;
}

/// Modelo de leitura para listas: junta nomes de conta e categoria sem
/// obrigar a interface a consultar a base.
class MovementListItem {
  const MovementListItem({
    required this.movement,
    required this.accountName,
    this.destinationAccountName,
    this.categoryName,
  });

  final Movement movement;
  final String accountName;
  final String? destinationAccountName;
  final String? categoryName;
}

class MovementTotals {
  const MovementTotals({required this.income, required this.expense});

  static const MovementTotals zero = MovementTotals(income: 0, expense: 0);

  final int income;
  final int expense;

  int get net => income - expense;

  /// Transferências ficam de fora: não são rendimento nem despesa.
  static MovementTotals of(Iterable<Movement> movements) {
    var income = 0;
    var expense = 0;
    for (final movement in movements) {
      switch (movement.kind) {
        case MovementKind.income:
          income += movement.amount;
        case MovementKind.expense:
          expense += movement.amount;
        case MovementKind.transfer:
          break;
      }
    }
    return MovementTotals(income: income, expense: expense);
  }
}

class MovementFilter {
  const MovementFilter({
    this.from,
    this.to,
    this.accountId,
    this.kind,
    this.categoryId,
    this.query,
  });

  /// Movimentos do mês de [month].
  factory MovementFilter.forMonth(DateTime month) {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1, 0);
    return MovementFilter(from: start, to: end);
  }

  final DateTime? from;
  final DateTime? to;
  final String? accountId;
  final MovementKind? kind;
  final String? categoryId;

  /// Pesquisa livre em descrição, notas, categoria e contas.
  final String? query;

  bool get hasQuery => query != null && query!.trim().isNotEmpty;

  bool get isActive =>
      from != null ||
      to != null ||
      accountId != null ||
      kind != null ||
      categoryId != null ||
      hasQuery;

  @override
  bool operator ==(Object other) =>
      other is MovementFilter &&
      other.from == from &&
      other.to == to &&
      other.accountId == accountId &&
      other.kind == kind &&
      other.categoryId == categoryId &&
      other.query == query;

  @override
  int get hashCode => Object.hash(from, to, accountId, kind, categoryId, query);
}

/// Movimento realizado de rendimento ou despesa. Transferências usam
/// [TransferDraft].
class MovementDraft {
  const MovementDraft({
    required this.kind,
    required this.amount,
    required this.date,
    required this.accountId,
    required this.categoryId,
    required this.description,
    this.notes,
  });

  final MovementKind kind;
  final int amount;
  final DateTime date;
  final String? accountId;
  final String? categoryId;
  final String description;
  final String? notes;

  Map<String, String> validate() {
    final errors = <String, String>{};
    if (kind.isTransfer) {
      errors['kind'] = 'Transferências usam o formulário próprio.';
    }
    if (amount <= 0) {
      errors['amount'] = 'Indique um montante superior a zero.';
    } else if (amount > MoneyInputParser.maxAmount) {
      errors['amount'] = 'Montante demasiado elevado.';
    }
    if (accountId == null || accountId!.isEmpty) {
      errors['accountId'] = 'Escolha a conta.';
    }
    if (categoryId == null || categoryId!.isEmpty) {
      errors['categoryId'] = 'Escolha a categoria.';
    }
    if (FinancialDate.dateOnly(date).isAfter(FinancialDate.today())) {
      errors['date'] = 'A data não pode ser futura.';
    }
    if (description.trim().length > 200) {
      errors['description'] = 'A descrição não pode exceder 200 caracteres.';
    }
    if ((notes ?? '').trim().length > 1000) {
      errors['notes'] = 'As notas não podem exceder 1000 caracteres.';
    }
    return errors;
  }
}

class TransferDraft {
  const TransferDraft({
    required this.sourceAccountId,
    required this.destinationAccountId,
    required this.amount,
    required this.date,
    required this.description,
  });

  final String? sourceAccountId;
  final String? destinationAccountId;
  final int amount;
  final DateTime date;
  final String description;

  Map<String, String> validate() {
    final errors = <String, String>{};
    if (sourceAccountId == null || sourceAccountId!.isEmpty) {
      errors['sourceAccountId'] = 'Escolha a conta de origem.';
    }
    if (destinationAccountId == null || destinationAccountId!.isEmpty) {
      errors['destinationAccountId'] = 'Escolha a conta de destino.';
    }
    if (sourceAccountId != null && sourceAccountId == destinationAccountId) {
      errors['destinationAccountId'] =
          'A conta de destino tem de ser diferente da origem.';
    }
    if (amount <= 0) {
      errors['amount'] = 'Indique um montante superior a zero.';
    } else if (amount > MoneyInputParser.maxAmount) {
      errors['amount'] = 'Montante demasiado elevado.';
    }
    if (FinancialDate.dateOnly(date).isAfter(FinancialDate.today())) {
      errors['date'] = 'A data não pode ser futura.';
    }
    if (description.trim().length > 200) {
      errors['description'] = 'A descrição não pode exceder 200 caracteres.';
    }
    return errors;
  }
}

class MovementListResult {
  const MovementListResult({required this.items, required this.totals});

  final List<MovementListItem> items;
  final MovementTotals totals;
}
