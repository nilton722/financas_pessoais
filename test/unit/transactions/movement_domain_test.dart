import 'package:financas_pessoais/features/transactions/domain/movement.dart';
import 'package:flutter_test/flutter_test.dart';

Movement _movement(MovementKind kind, int amount) => Movement(
  id: 'movement-$kind-$amount',
  kind: kind,
  accountId: 'account-1',
  amount: amount,
  date: DateTime.now(),
);

void main() {
  group('MovementTotals', () {
    test('ignora transferências', () {
      final totals = MovementTotals.of([
        _movement(MovementKind.income, 5000),
        _movement(MovementKind.income, 1500),
        _movement(MovementKind.expense, 2000),
        _movement(MovementKind.transfer, 7000),
      ]);

      expect(totals.income, 6500);
      expect(totals.expense, 2000);
      expect(totals.net, 4500);
    });

    test('lista vazia resulta em zero', () {
      final totals = MovementTotals.of(const []);
      expect(totals.income, 0);
      expect(totals.expense, 0);
    });
  });

  group('MovementDraft.validate', () {
    MovementDraft draft({
      MovementKind kind = MovementKind.expense,
      int amount = 1000,
      String? accountId = 'account-1',
      String? categoryId = 'category-1',
      DateTime? date,
      String description = '',
      String? notes,
    }) {
      return MovementDraft(
        kind: kind,
        amount: amount,
        date: date ?? DateTime.now(),
        accountId: accountId,
        categoryId: categoryId,
        description: description,
        notes: notes,
      );
    }

    test('aceita dados válidos', () {
      expect(draft().validate(), isEmpty);
    });

    test('rejeita montante zero ou negativo', () {
      expect(draft(amount: 0).validate()['amount'], isNotNull);
      expect(draft(amount: -1).validate()['amount'], isNotNull);
    });

    test('rejeita conta ou categoria ausente', () {
      expect(draft(accountId: null).validate()['accountId'], isNotNull);
      expect(draft(categoryId: null).validate()['categoryId'], isNotNull);
    });

    test('rejeita data futura', () {
      final future = DateTime.now().add(const Duration(days: 3));
      expect(draft(date: future).validate()['date'], isNotNull);
    });

    test('rejeita tipo transferência', () {
      expect(draft(kind: MovementKind.transfer).validate()['kind'], isNotNull);
    });

    test('limita descrição e notas', () {
      expect(
        draft(description: 'a' * 201).validate()['description'],
        isNotNull,
      );
      expect(draft(notes: 'a' * 1001).validate()['notes'], isNotNull);
    });
  });

  group('TransferDraft.validate', () {
    TransferDraft draft({
      String? sourceAccountId = 'account-1',
      String? destinationAccountId = 'account-2',
      int amount = 1000,
      DateTime? date,
    }) {
      return TransferDraft(
        sourceAccountId: sourceAccountId,
        destinationAccountId: destinationAccountId,
        amount: amount,
        date: date ?? DateTime.now(),
        description: 'Transferência',
      );
    }

    test('aceita contas distintas e montante positivo', () {
      expect(draft().validate(), isEmpty);
    });

    test('exige contas de origem e destino', () {
      expect(
        draft(sourceAccountId: null).validate()['sourceAccountId'],
        isNotNull,
      );
      expect(
        draft(destinationAccountId: null).validate()['destinationAccountId'],
        isNotNull,
      );
    });

    test('rejeita origem igual ao destino', () {
      expect(
        draft(destinationAccountId: 'account-1')
            .validate()['destinationAccountId'],
        isNotNull,
      );
    });

    test('rejeita montante não positivo', () {
      expect(draft(amount: 0).validate()['amount'], isNotNull);
    });
  });

  group('MovementFilter', () {
    test('forMonth cobre o primeiro e o último dia do mês', () {
      final filter = MovementFilter.forMonth(DateTime(2026, 2, 15));
      expect(filter.from, DateTime(2026, 2, 1));
      expect(filter.to, DateTime(2026, 2, 28));
    });

    test('filtro vazio não está ativo', () {
      expect(const MovementFilter().isActive, isFalse);
      expect(MovementFilter.forMonth(DateTime(2026, 2)).isActive, isTrue);
    });

    test('igualdade compara todos os campos', () {
      const a = MovementFilter(kind: MovementKind.expense, accountId: 'a');
      const b = MovementFilter(kind: MovementKind.expense, accountId: 'a');
      const c = MovementFilter(kind: MovementKind.income, accountId: 'a');

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });
}
