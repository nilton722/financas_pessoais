import '../../../core/formatters/date_formatter.dart';
import '../../../core/formatters/money_input_parser.dart';

/// Os orçamentos são mensais; o período é sempre o primeiro dia do mês.
abstract final class BudgetPeriod {
  static DateTime monthStart(DateTime date) => DateTime(date.year, date.month);

  static DateTime monthEnd(DateTime date) =>
      DateTime(date.year, date.month + 1, 0);

  static String dbValue(DateTime date) =>
      FinancialDate.fromDateTime(monthStart(date));
}

/// Limite mensal por categoria. [spent] é sempre calculado a partir dos
/// movimentos reais de despesa; transferências e rendimentos ficam de fora.
class Budget {
  const Budget({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.periodStart,
    required this.limitAmount,
    required this.spent,
    this.categoryArchived = false,
  });

  final String id;
  final String categoryId;
  final String categoryName;
  final DateTime periodStart;
  final int limitAmount;
  final int spent;
  final bool categoryArchived;

  int get remaining => limitAmount - spent;

  bool get isExceeded => spent > limitAmount;

  /// Percentagem gasta, sem limite superior: 120% é informação útil.
  double get percent {
    if (limitAmount <= 0) {
      return spent > 0 ? 100 : 0;
    }
    return spent / limitAmount * 100;
  }

  /// Fração para barras de progresso, limitada a 100%.
  double get progress {
    if (limitAmount <= 0) {
      return spent > 0 ? 1 : 0;
    }
    final value = spent / limitAmount;
    return value < 0 ? 0 : (value > 1 ? 1 : value);
  }
}

class BudgetDraft {
  const BudgetDraft({
    required this.categoryId,
    required this.limitAmount,
    required this.periodStart,
  });

  final String? categoryId;
  final int limitAmount;
  final DateTime periodStart;

  Map<String, String> validate() {
    final errors = <String, String>{};
    if (categoryId == null || categoryId!.isEmpty) {
      errors['categoryId'] = 'Escolha uma categoria de despesa.';
    }
    if (limitAmount < 0) {
      errors['limitAmount'] = 'O limite não pode ser negativo.';
    } else if (limitAmount > MoneyInputParser.maxAmount) {
      errors['limitAmount'] = 'Limite demasiado elevado.';
    }
    return errors;
  }
}
