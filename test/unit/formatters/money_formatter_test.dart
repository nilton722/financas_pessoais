import 'package:financas_pessoais/core/formatters/money_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

String _normalize(String value) =>
    value.replaceAll(RegExp(r'[\s\u00a0\u202f]'), ' ');

void main() {
  group('MoneyFormatter.formatXof', () {
    test('formata zero', () {
      expect(MoneyFormatter.formatXof(0), '0 FCFA');
    });

    test('usa inteiros sem casas decimais', () {
      expect(MoneyFormatter.formatXof(1), '1 FCFA');
      expect(MoneyFormatter.formatXof(999), '999 FCFA');
    });

    test('agrupa milhares', () {
      expect(_normalize(MoneyFormatter.formatXof(12500)), '12 500 FCFA');
      expect(_normalize(MoneyFormatter.formatXof(1000000)), '1 000 000 FCFA');
    });

    test('formata saldos negativos', () {
      expect(_normalize(MoneyFormatter.formatXof(-12500)), '-12 500 FCFA');
    });

    test('formata o montante máximo sem perda de precisão', () {
      expect(
        _normalize(MoneyFormatter.formatXof(999999999999)),
        '999 999 999 999 FCFA',
      );
    });
  });
}
