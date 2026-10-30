/// Datas financeiras circulam como `YYYY-MM-DD` e são apresentadas como
/// `DD/MM/YYYY`. Timestamps técnicos usam ISO-8601 UTC (ver `core/utils`).
abstract final class FinancialDate {
  static final RegExp _pattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  static String fromDateTime(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static String toDisplay(String financialDate) {
    final parsed = tryParse(financialDate);
    if (parsed == null) {
      throw FormatException('Data financeira inválida', financialDate);
    }
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    return '$day/$month/${parsed.year}';
  }

  static DateTime? tryParse(String value) {
    final match = _pattern.firstMatch(value);
    if (match == null) {
      return null;
    }
    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    if (month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }
    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return parsed;
  }

  /// Data sem componente horária, para comparações de dias.
  static DateTime dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime today() => dateOnly(DateTime.now());
}
