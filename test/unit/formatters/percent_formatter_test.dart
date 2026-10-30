import 'package:financas_pessoais/core/formatters/percent_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PercentFormatter.format', () {
    test('formata valores inteiros e frações curtas', () {
      expect(PercentFormatter.format(0), '0%');
      expect(PercentFormatter.format(50), '50%');
      expect(PercentFormatter.format(60), '60%');
      expect(PercentFormatter.format(12.34), '12,3%');
    });

    test('não mostra casas decimais em 100% ou acima', () {
      expect(PercentFormatter.format(100), '100%');
      expect(PercentFormatter.format(100.4), '100%');
      expect(PercentFormatter.format(125.5), '126%');
    });

    test('protege contra valores não finitos', () {
      expect(PercentFormatter.format(double.nan), '0%');
      expect(PercentFormatter.format(double.infinity), '0%');
    });
  });
}
