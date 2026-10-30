import 'package:financas_pessoais/core/formatters/date_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FinancialDate', () {
    test('converte DateTime para YYYY-MM-DD com zero à esquerda', () {
      expect(FinancialDate.fromDateTime(DateTime(2026, 1, 5)), '2026-01-05');
      expect(FinancialDate.fromDateTime(DateTime(2028, 2, 29)), '2028-02-29');
    });

    test('apresenta como DD/MM/YYYY', () {
      expect(FinancialDate.toDisplay('2026-01-05'), '05/01/2026');
      expect(FinancialDate.toDisplay('2028-02-29'), '29/02/2028');
    });

    test('rejeita formatos e datas inválidas', () {
      expect(
        () => FinancialDate.toDisplay('05/01/2026'),
        throwsFormatException,
      );
      expect(
        () => FinancialDate.toDisplay('2026-02-30'),
        throwsFormatException,
      );
      expect(
        () => FinancialDate.toDisplay('2026-13-01'),
        throwsFormatException,
      );
      expect(FinancialDate.tryParse('2026-1-5'), isNull);
      expect(FinancialDate.tryParse('2026-12-31'), DateTime(2026, 12, 31));
    });

    test('identifica ano bissexto', () {
      expect(FinancialDate.tryParse('2027-02-29'), isNull);
      expect(FinancialDate.tryParse('2028-02-29'), DateTime(2028, 2, 29));
    });
  });
}
