import '../../../core/formatters/date_formatter.dart';
import '../../../core/formatters/money_input_parser.dart';

enum DebtKind {
  payable('payable', 'A pagar'),
  receivable('receivable', 'A receber');

  const DebtKind(this.dbValue, this.label);

  final String dbValue;
  final String label;

  /// Uma dívida a pagar liquida-se com uma despesa; a receber, com um
  /// rendimento.
  String get movementKind => this == DebtKind.payable ? 'expense' : 'income';

  static DebtKind fromDb(String value) => values.firstWhere(
    (kind) => kind.dbValue == value,
    orElse: () => DebtKind.payable,
  );
}

enum DebtStatus {
  open('open', 'Em aberto'),
  paid('paid', 'Liquidada'),
  cancelled('cancelled', 'Cancelada');

  const DebtStatus(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static DebtStatus fromDb(String value) => values.firstWhere(
    (status) => status.dbValue == value,
    orElse: () => DebtStatus.open,
  );
}

/// Dívida a pagar ou a receber. O pendente deriva dos pagamentos reais
/// (movimentos não eliminados); a dívida em si nunca altera o caixa.
class Debt {
  const Debt({
    required this.id,
    required this.kind,
    required this.description,
    required this.originalAmount,
    required this.status,
    required this.paidTotal,
    this.counterparty,
    this.dueDate,
  });

  final String id;
  final DebtKind kind;
  final String description;
  final int originalAmount;
  final DebtStatus status;
  final int paidTotal;
  final String? counterparty;
  final DateTime? dueDate;

  int get remaining {
    final value = originalAmount - paidTotal;
    return value < 0 ? 0 : value;
  }

  DebtStatus get effectiveStatus {
    if (status == DebtStatus.cancelled) {
      return DebtStatus.cancelled;
    }
    if (paidTotal >= originalAmount) {
      return DebtStatus.paid;
    }
    return DebtStatus.open;
  }

  bool get isOpen => effectiveStatus == DebtStatus.open;

  double get progress {
    if (originalAmount <= 0) {
      return 0;
    }
    final value = paidTotal / originalAmount;
    return value < 0 ? 0 : (value > 1 ? 1 : value);
  }

  bool isOverdue(DateTime today) {
    final due = dueDate;
    if (due == null || !isOpen) {
      return false;
    }
    return FinancialDate.dateOnly(due).isBefore(FinancialDate.dateOnly(today));
  }
}

class DebtDraft {
  const DebtDraft({
    required this.kind,
    required this.description,
    required this.originalAmount,
    this.counterparty,
    this.dueDate,
  });

  final DebtKind kind;
  final String description;
  final int originalAmount;
  final String? counterparty;
  final DateTime? dueDate;

  Map<String, String> validate() {
    final errors = <String, String>{};
    if (description.trim().isEmpty) {
      errors['description'] = 'Indique uma descrição.';
    } else if (description.trim().length > 200) {
      errors['description'] = 'A descrição não pode exceder 200 caracteres.';
    }
    if (originalAmount <= 0) {
      errors['originalAmount'] = 'Indique um valor superior a zero.';
    } else if (originalAmount > MoneyInputParser.maxAmount) {
      errors['originalAmount'] = 'Valor demasiado elevado.';
    }
    if ((counterparty ?? '').trim().length > 80) {
      errors['counterparty'] = 'O nome não pode exceder 80 caracteres.';
    }
    return errors;
  }
}

class DebtPayment {
  const DebtPayment({
    required this.id,
    required this.debtId,
    required this.transactionId,
    required this.amount,
    required this.date,
    this.description,
  });

  final String id;
  final String debtId;
  final String transactionId;
  final int amount;
  final DateTime date;
  final String? description;
}

class DebtPaymentDraft {
  const DebtPaymentDraft({
    required this.amount,
    required this.date,
    required this.accountId,
    required this.categoryId,
    this.description,
  });

  final int amount;
  final DateTime date;
  final String? accountId;
  final String? categoryId;
  final String? description;

  Map<String, String> validate({required int remaining}) {
    final errors = <String, String>{};
    if (remaining <= 0) {
      errors['amount'] = 'A dívida já está liquidada.';
    } else if (amount <= 0) {
      errors['amount'] = 'Indique um valor superior a zero.';
    } else if (amount > remaining) {
      errors['amount'] = 'O pagamento excede o valor em falta.';
    } else if (amount > MoneyInputParser.maxAmount) {
      errors['amount'] = 'Valor demasiado elevado.';
    }
    if (accountId == null || accountId!.isEmpty) {
      errors['accountId'] = 'Escolha a conta do movimento.';
    }
    if (categoryId == null || categoryId!.isEmpty) {
      errors['categoryId'] = 'Escolha a categoria do movimento.';
    }
    if (FinancialDate.dateOnly(date).isAfter(FinancialDate.today())) {
      errors['date'] = 'A data do pagamento não pode ser futura.';
    }
    if ((description ?? '').trim().length > 200) {
      errors['description'] = 'A descrição não pode exceder 200 caracteres.';
    }
    return errors;
  }
}
