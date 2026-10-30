/// Pluralização simples para contagens visíveis na interface.
///
/// Recebe as duas formas porque o português não segue uma regra única
/// (`meta`/`metas`, `milhão`/`milhões`).
abstract final class PluralFormatter {
  static String count(int value, String singular, String plural) =>
      '$value ${value == 1 ? singular : plural}';
}
