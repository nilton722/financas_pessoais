/// FCFA/XOF não tem casas decimais: a entrada é sempre um inteiro.
abstract final class MoneyInputParser {
  static const int maxAmount = 999999999999;

  static final RegExp _digitsOnly = RegExp(r'^\d{1,12}$');
  static final RegExp _spaces = RegExp(r'[\s\u00a0\u202f]');

  /// Devolve `null` para entradas ambíguas (casas decimais, sinais, letras)
  /// em vez de adivinhar, para nunca alterar o valor em silêncio.
  static int? parseXof(String raw) {
    final cleaned = raw.replaceAll(_spaces, '');
    if (!_digitsOnly.hasMatch(cleaned)) {
      return null;
    }
    final value = int.tryParse(cleaned);
    if (value == null || value > maxAmount) {
      return null;
    }
    return value;
  }

  static String? validate(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return 'Indique o montante em FCFA.';
    }
    if (parseXof(raw) == null) {
      return 'Use um número inteiro de FCFA, sem casas decimais.';
    }
    return null;
  }

  static String formatPlain(int amount) => amount.toString();
}
