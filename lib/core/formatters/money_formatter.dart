import 'package:intl/intl.dart';

/// Montantes são inteiros em FCFA/XOF: sem casas decimais e sem `double`.
abstract final class MoneyFormatter {
  static const String xofSymbol = 'FCFA';

  static final NumberFormat _xofGrouped = NumberFormat.decimalPatternDigits(
    locale: 'pt_PT',
    decimalDigits: 0,
  );

  static String formatXof(int amount) =>
      '${_xofGrouped.format(amount)} $xofSymbol';
}
