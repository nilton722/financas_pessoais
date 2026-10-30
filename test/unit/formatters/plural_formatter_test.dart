import 'package:financas_pessoais/core/formatters/plural_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PluralFormatter.count', () {
    test('usa singular apenas para uma unidade', () {
      expect(PluralFormatter.count(0, 'meta', 'metas'), '0 metas');
      expect(PluralFormatter.count(1, 'meta', 'metas'), '1 meta');
      expect(PluralFormatter.count(2, 'meta', 'metas'), '2 metas');
    });

    test('aceita formas irregulares', () {
      expect(PluralFormatter.count(1, 'milhão', 'milhões'), '1 milhão');
      expect(PluralFormatter.count(3, 'milhão', 'milhões'), '3 milhões');
    });
  });
}
