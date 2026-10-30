import '../../../core/formatters/date_formatter.dart';
import '../../../core/formatters/money_input_parser.dart';
import 'planned_item.dart';

enum RecurrenceFrequency {
  weekly('weekly', 'Semanal'),
  monthly('monthly', 'Mensal'),
  yearly('yearly', 'Anual');

  const RecurrenceFrequency(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static RecurrenceFrequency fromDb(String value) => values.firstWhere(
    (frequency) => frequency.dbValue == value,
    orElse: () => RecurrenceFrequency.monthly,
  );

  /// Data da ocorrência [index] (0 = início). As datas derivam sempre do
  /// início: 31 de janeiro gera 28/29 de fevereiro e volta a 31 de março, em
  /// vez de "colar" no dia 28 para sempre.
  DateTime dateFor(DateTime start, int index) {
    final anchor = FinancialDate.dateOnly(start);
    switch (this) {
      case RecurrenceFrequency.weekly:
        return anchor.add(Duration(days: 7 * index));
      case RecurrenceFrequency.monthly:
        return _addMonthsClamped(anchor, index);
      case RecurrenceFrequency.yearly:
        return _addMonthsClamped(anchor, 12 * index);
    }
  }

  static DateTime _addMonthsClamped(DateTime start, int months) {
    final monthIndex = start.month - 1 + months;
    final year = start.year + monthIndex ~/ 12;
    final month = monthIndex % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    final day = start.day > lastDay ? lastDay : start.day;
    return DateTime(year, month, day);
  }
}

class RecurringRule {
  const RecurringRule({
    required this.id,
    required this.kind,
    required this.amount,
    required this.frequency,
    required this.startDate,
    required this.nextOccurrenceDate,
    required this.description,
    required this.isActive,
    this.endDate,
    this.accountId,
    this.categoryId,
    this.accountName,
    this.categoryName,
  });

  final String id;
  final PlannedItemKind kind;
  final int amount;
  final RecurrenceFrequency frequency;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime nextOccurrenceDate;
  final String description;
  final bool isActive;
  final String? accountId;
  final String? categoryId;
  final String? accountName;
  final String? categoryName;

  bool get hasEnded {
    final end = endDate;
    return end != null &&
        FinancialDate.dateOnly(nextOccurrenceDate)
            .isAfter(FinancialDate.dateOnly(end));
  }
}

class RecurringRuleDraft {
  const RecurringRuleDraft({
    required this.kind,
    required this.amount,
    required this.frequency,
    required this.startDate,
    required this.description,
    this.endDate,
    this.accountId,
    this.categoryId,
  });

  final PlannedItemKind kind;
  final int amount;
  final RecurrenceFrequency frequency;
  final DateTime startDate;
  final DateTime? endDate;
  final String description;
  final String? accountId;
  final String? categoryId;

  DateTime get initialNextOccurrence => frequency.dateFor(startDate, 0);

  Map<String, String> validate() {
    final errors = <String, String>{};
    if (amount <= 0) {
      errors['amount'] = 'Indique um valor superior a zero.';
    } else if (amount > MoneyInputParser.maxAmount) {
      errors['amount'] = 'Valor demasiado elevado.';
    }
    if (description.trim().isEmpty) {
      errors['description'] = 'Indique uma descrição.';
    } else if (description.trim().length > 200) {
      errors['description'] = 'A descrição não pode exceder 200 caracteres.';
    }
    final end = endDate;
    if (end != null &&
        FinancialDate.dateOnly(end)
            .isBefore(FinancialDate.dateOnly(startDate))) {
      errors['endDate'] = 'O fim não pode ser anterior ao início.';
    }
    return errors;
  }
}
