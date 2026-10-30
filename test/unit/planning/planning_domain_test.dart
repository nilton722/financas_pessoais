import 'package:financas_pessoais/features/planning/domain/planned_item.dart';
import 'package:financas_pessoais/features/planning/domain/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RecurrenceFrequency.dateFor', () {
    test('semanal avança sete dias por ocorrência', () {
      final start = DateTime(2026, 1, 31);
      expect(
        RecurrenceFrequency.weekly.dateFor(start, 0),
        DateTime(2026, 1, 31),
      );
      expect(
        RecurrenceFrequency.weekly.dateFor(start, 3),
        DateTime(2026, 2, 21),
      );
    });

    test('mensal ancora no dia original e ajusta meses curtos', () {
      final start = DateTime(2026, 1, 31);
      expect(
        RecurrenceFrequency.monthly.dateFor(start, 1),
        DateTime(2026, 2, 28),
      );
      expect(
        RecurrenceFrequency.monthly.dateFor(start, 2),
        DateTime(2026, 3, 31),
      );
      expect(
        RecurrenceFrequency.monthly.dateFor(start, 3),
        DateTime(2026, 4, 30),
      );
    });

    test('anual mantém o dia, incluindo 29 de fevereiro', () {
      final start = DateTime(2024, 2, 29);
      expect(
        RecurrenceFrequency.yearly.dateFor(start, 1),
        DateTime(2025, 2, 28),
      );
      expect(
        RecurrenceFrequency.yearly.dateFor(start, 4),
        DateTime(2028, 2, 29),
      );
    });
  });

  group('PlannedItem', () {
    PlannedItem item({
      int amount = 1000,
      int paidTotal = 0,
      PlannedItemStatus status = PlannedItemStatus.planned,
    }) {
      return PlannedItem(
        id: 'item',
        kind: PlannedItemKind.expense,
        amount: amount,
        dueDate: DateTime(2026, 10, 30),
        description: 'Renda',
        status: status,
        paidTotal: paidTotal,
      );
    }

    test('estado efetivo deriva do total pago', () {
      expect(item().effectiveStatus, PlannedItemStatus.planned);
      expect(
        item(paidTotal: 400).effectiveStatus,
        PlannedItemStatus.partiallyPaid,
      );
      expect(item(paidTotal: 1000).effectiveStatus, PlannedItemStatus.paid);
      expect(
        item(
          paidTotal: 1000,
          status: PlannedItemStatus.cancelled,
        ).effectiveStatus,
        PlannedItemStatus.cancelled,
      );
    });

    test('restante nunca é negativo', () {
      expect(item(paidTotal: 300).remaining, 700);
      expect(item(paidTotal: 1200).remaining, 0);
    });

    test('vencido e a vencer ignoram compromissos liquidados', () {
      final today = DateTime(2026, 10, 30);
      expect(item().isOverdue(DateTime(2026, 10, 31)), isTrue);
      expect(item().isDueWithin(today, days: 3), isTrue);
      expect(item(paidTotal: 1000).isOverdue(DateTime(2026, 10, 31)), isFalse);
      expect(
        item(status: PlannedItemStatus.cancelled).isDueWithin(today, days: 3),
        isFalse,
      );
    });
  });

  group('validações', () {
    test('compromisso exige valor e descrição', () {
      final errors = PlannedItemDraft(
        kind: PlannedItemKind.expense,
        amount: 0,
        dueDate: DateTime(2026, 11, 1),
        description: '  ',
      ).validate();
      expect(errors.keys, containsAll(['amount', 'description']));
    });

    test('pagamento não pode exceder o restante', () {
      final errors = PaymentDraft(
        amount: 900,
        date: DateTime(2026, 10, 30),
        accountId: 'account-1',
      ).validate(remaining: 500);
      expect(errors['amount'], isNotNull);
    });

    test('pagamento exige conta e não aceita data futura', () {
      final future = DateTime.now().add(const Duration(days: 2));
      final errors = PaymentDraft(
        amount: 100,
        date: future,
      ).validate(remaining: 500);
      expect(errors.keys, containsAll(['accountId', 'date']));
    });

    test('recorrência exige fim posterior ao início', () {
      final errors = RecurringRuleDraft(
        kind: PlannedItemKind.expense,
        amount: 1000,
        frequency: RecurrenceFrequency.monthly,
        startDate: DateTime(2026, 5, 10),
        endDate: DateTime(2026, 5, 9),
        description: 'Renda',
      ).validate();
      expect(errors['endDate'], isNotNull);
    });
  });
}
