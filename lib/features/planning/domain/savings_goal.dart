import '../../../core/formatters/date_formatter.dart';
import '../../../core/formatters/money_input_parser.dart';

/// Meta de poupança. Não é uma despesa: o progresso vem do saldo real da
/// conta associada (ou é zero quando não há conta associada).
class SavingsGoal {
  const SavingsGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    required this.isArchived,
    this.targetDate,
    this.linkedAccountId,
    this.linkedAccountName,
    this.notes,
  });

  final String id;
  final String name;
  final int targetAmount;
  final int currentAmount;
  final bool isArchived;
  final DateTime? targetDate;
  final String? linkedAccountId;
  final String? linkedAccountName;
  final String? notes;

  int get remaining {
    final value = targetAmount - currentAmount;
    return value < 0 ? 0 : value;
  }

  bool get isReached => currentAmount >= targetAmount;

  double get progress {
    if (targetAmount <= 0) {
      return 0;
    }
    final value = currentAmount / targetAmount;
    return value < 0 ? 0 : (value > 1 ? 1 : value);
  }

  bool isOverdue(DateTime today) {
    final due = targetDate;
    if (due == null || isReached) {
      return false;
    }
    return FinancialDate.dateOnly(due).isBefore(FinancialDate.dateOnly(today));
  }
}

class SavingsGoalDraft {
  const SavingsGoalDraft({
    required this.name,
    required this.targetAmount,
    this.targetDate,
    this.linkedAccountId,
    this.notes,
  });

  final String name;
  final int targetAmount;
  final DateTime? targetDate;
  final String? linkedAccountId;
  final String? notes;

  Map<String, String> validate() {
    final errors = <String, String>{};
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      errors['name'] = 'Indique o nome da meta.';
    } else if (trimmedName.length > 60) {
      errors['name'] = 'O nome não pode exceder 60 caracteres.';
    }
    if (targetAmount <= 0) {
      errors['targetAmount'] = 'Indique um alvo superior a zero.';
    } else if (targetAmount > MoneyInputParser.maxAmount) {
      errors['targetAmount'] = 'Alvo demasiado elevado.';
    }
    if ((notes ?? '').trim().length > 500) {
      errors['notes'] = 'As notas não podem exceder 500 caracteres.';
    }
    return errors;
  }
}
