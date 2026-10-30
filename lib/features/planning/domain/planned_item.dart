import '../../../core/formatters/date_formatter.dart';
import '../../../core/formatters/money_input_parser.dart';

enum PlannedItemKind {
  income('income', 'Rendimento'),
  expense('expense', 'Despesa');

  const PlannedItemKind(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static PlannedItemKind fromDb(String value) => values.firstWhere(
    (kind) => kind.dbValue == value,
    orElse: () => PlannedItemKind.expense,
  );
}

/// Estado guardado do compromisso. O estado apresentado é sempre derivado do
/// total efetivamente pago ([PlannedItem.effectiveStatus]), porque um
/// movimento pode ser eliminado sem alterar a linha do compromisso.
enum PlannedItemStatus {
  planned('planned', 'Planeado'),
  partiallyPaid('partially_paid', 'Parcialmente pago'),
  paid('paid', 'Pago'),
  cancelled('cancelled', 'Cancelado');

  const PlannedItemStatus(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static PlannedItemStatus fromDb(String value) => values.firstWhere(
    (status) => status.dbValue == value,
    orElse: () => PlannedItemStatus.planned,
  );
}

/// Compromisso futuro. Nunca entra no saldo: apenas o movimento real criado
/// ao pagar tem efeito no caixa.
class PlannedItem {
  const PlannedItem({
    required this.id,
    required this.kind,
    required this.amount,
    required this.dueDate,
    required this.description,
    required this.status,
    required this.paidTotal,
    this.accountId,
    this.categoryId,
    this.transactionId,
    this.accountName,
    this.categoryName,
  });

  final String id;
  final PlannedItemKind kind;
  final int amount;
  final DateTime dueDate;
  final String description;
  final PlannedItemStatus status;
  final int paidTotal;
  final String? accountId;
  final String? categoryId;
  final String? transactionId;
  final String? accountName;
  final String? categoryName;

  int get remaining {
    final value = amount - paidTotal;
    return value < 0 ? 0 : value;
  }

  /// Derivado, não guardado: cancelado prevalece; pago quando o total
  /// alocado cobre o valor; parcial quando existe algum pagamento real.
  PlannedItemStatus get effectiveStatus {
    if (status == PlannedItemStatus.cancelled) {
      return PlannedItemStatus.cancelled;
    }
    if (paidTotal >= amount) {
      return PlannedItemStatus.paid;
    }
    if (paidTotal > 0) {
      return PlannedItemStatus.partiallyPaid;
    }
    return PlannedItemStatus.planned;
  }

  bool get isOpen =>
      effectiveStatus == PlannedItemStatus.planned ||
      effectiveStatus == PlannedItemStatus.partiallyPaid;

  bool get isSettled => !isOpen;

  double get progress {
    if (amount <= 0) {
      return 0;
    }
    final value = paidTotal / amount;
    return value < 0 ? 0 : (value > 1 ? 1 : value);
  }

  bool isOverdue(DateTime today) {
    if (!isOpen) {
      return false;
    }
    return FinancialDate.dateOnly(dueDate)
        .isBefore(FinancialDate.dateOnly(today));
  }

  bool isDueWithin(DateTime today, {int days = 7}) {
    if (!isOpen) {
      return false;
    }
    final reference = FinancialDate.dateOnly(today);
    final due = FinancialDate.dateOnly(dueDate);
    if (due.isBefore(reference)) {
      return false;
    }
    return !due.isAfter(reference.add(Duration(days: days)));
  }
}

/// Um pagamento real alocado a um compromisso. Cada linha corresponde a um
/// movimento em `transactions`; eliminar o movimento liberta a alocação.
class PlannedPayment {
  const PlannedPayment({
    required this.id,
    required this.plannedItemId,
    required this.transactionId,
    required this.amount,
    required this.date,
    this.description,
  });

  final String id;
  final String plannedItemId;
  final String transactionId;
  final int amount;
  final DateTime date;
  final String? description;
}

class PlannedItemDraft {
  const PlannedItemDraft({
    required this.kind,
    required this.amount,
    required this.dueDate,
    required this.description,
    this.accountId,
    this.categoryId,
  });

  final PlannedItemKind kind;
  final int amount;
  final DateTime dueDate;
  final String description;
  final String? accountId;
  final String? categoryId;

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
    if (FinancialDate.tryParse(FinancialDate.fromDateTime(dueDate)) == null) {
      errors['dueDate'] = 'Indique uma data de vencimento válida.';
    }
    return errors;
  }
}

/// Pagamento (total ou parcial) de um compromisso. O montante é validado
/// contra o restante, para que a soma das alocações nunca exceda o valor.
class PaymentDraft {
  const PaymentDraft({
    required this.amount,
    required this.date,
    this.accountId,
    this.categoryId,
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
      errors['amount'] = 'O compromisso já está liquidado.';
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
    if (FinancialDate.dateOnly(date).isAfter(FinancialDate.today())) {
      errors['date'] = 'A data do pagamento não pode ser futura.';
    }
    if ((description ?? '').trim().length > 200) {
      errors['description'] = 'A descrição não pode exceder 200 caracteres.';
    }
    return errors;
  }
}
