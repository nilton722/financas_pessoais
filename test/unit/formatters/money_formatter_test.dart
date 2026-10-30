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

  group('MoneyFormatter.formatXofSigned', () {
    test('mostra o sinal em entradas positivas', () {
      expect(_normalize(MoneyFormatter.formatXofSigned(12500)), '+12 500 FCFA');
    });

    test('mantém o sinal negativo e o zero', () {
      expect(
        _normalize(MoneyFormatter.formatXofSigned(-12500)),
        '-12 500 FCFA',
      );
      expect(MoneyFormatter.formatXofSigned(0), '0 FCFA');
    });
  });

  group('MoneyFormatter.formatXofCompact', () {
    test('abaixo de um milhão mantém o valor exato', () {
      expect(
        _normalize(MoneyFormatter.formatXofCompact(999999)),
        '999 999 FCFA',
      );
    });

    test('usa milhões com vírgula decimal portuguesa', () {
      expect(
        _normalize(MoneyFormatter.formatXofCompact(1250000)),
        '1,25 M FCFA',
      );
    });

    test('usa mil milhões acima de 10^9', () {
      expect(
        _normalize(MoneyFormatter.formatXofCompact(1250000000)),
        '1,25 mil M FCFA',
      );
    });

    test('preserva o sinal negativo', () {
      expect(
        _normalize(MoneyFormatter.formatXofCompact(-7500000)),
        '-7,5 M FCFA',
      );
    });

    test('versão com sinal explícito', () {
      expect(
        _normalize(MoneyFormatter.formatXofCompactSigned(2500000)),
        '+2,5 M FCFA',
      );
      expect(
        _normalize(MoneyFormatter.formatXofCompactSigned(-2500000)),
        '-2,5 M FCFA',
      );
    });
  });
}
