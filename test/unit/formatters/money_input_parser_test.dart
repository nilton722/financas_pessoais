import 'package:financas_pessoais/core/formatters/money_input_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MoneyInputParser.parseXof', () {
    test('lê inteiros simples', () {
      expect(MoneyInputParser.parseXof('1500'), 1500);
      expect(MoneyInputParser.parseXof('0'), 0);
    });

    test('ignora espaços, incluindo espaços finos', () {
      expect(MoneyInputParser.parseXof(' 1 500 '), 1500);
      expect(MoneyInputParser.parseXof('1\u00a0500'), 1500);
      expect(MoneyInputParser.parseXof('1\u202f500'), 1500);
    });

    test('rejeita casas decimais, sinais e letras', () {
      expect(MoneyInputParser.parseXof('12.5'), isNull);
      expect(MoneyInputParser.parseXof('12,5'), isNull);
      expect(MoneyInputParser.parseXof('-10'), isNull);
      expect(MoneyInputParser.parseXof('abc'), isNull);
      expect(MoneyInputParser.parseXof(''), isNull);
    });

    test('respeita o montante máximo', () {
      expect(MoneyInputParser.parseXof('999999999999'), 999999999999);
      expect(MoneyInputParser.parseXof('1000000000000'), isNull);
    });
  });

  group('MoneyInputParser.validate', () {
    test('exige valor', () {
      expect(MoneyInputParser.validate(null), 'Indique o montante em FCFA.');
      expect(MoneyInputParser.validate('  '), 'Indique o montante em FCFA.');
    });

    test('explica o formato inteiro', () {
      expect(
        MoneyInputParser.validate('1,5'),
        'Use um número inteiro de FCFA, sem casas decimais.',
      );
    });

    test('aceita inteiro válido', () {
      expect(MoneyInputParser.validate('2500'), isNull);
    });
  });

  test('formatPlain devolve o valor sem separadores', () {
    expect(MoneyInputParser.formatPlain(1234567), '1234567');
  });
}
