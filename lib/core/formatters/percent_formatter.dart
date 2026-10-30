import 'package:intl/intl.dart';

/// Percentagens apresentadas em português: vírgula decimal, sem `%` redundante
/// e no máximo uma casa decimal.
abstract final class PercentFormatter {
  static final NumberFormat _compact = NumberFormat('#,##0.#', 'pt_PT');

  /// Recebe o valor já em percentagem (0–100), não a fração.
  static String format(double percent) {
    if (!percent.isFinite) {
      return '0%';
    }
    final rounded = percent >= 100 ? percent.roundToDouble() : percent;
    return '${_compact.format(rounded)}%';
  }
}
