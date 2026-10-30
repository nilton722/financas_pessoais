import 'package:intl/intl.dart';

/// Montantes são inteiros em FCFA/XOF: sem casas decimais e sem `double`.
abstract final class MoneyFormatter {
  static const String xofSymbol = 'FCFA';

  /// A partir deste valor os resumos usam notação compacta (ex.: `1,25 M`).
  /// Listas, formulários e relatórios continuam a mostrar o valor exato.
  static const int compactThreshold = 1000000;

  static final NumberFormat _xofGrouped = NumberFormat.decimalPatternDigits(
    locale: 'pt_PT',
    decimalDigits: 0,
  );

  static final NumberFormat _compact = NumberFormat('#,##0.##', 'pt_PT');

  /// Valor exato, com agrupamento de milhares e sufixo `FCFA`.
  static String formatXof(int amount) =>
      '${_xofGrouped.format(amount)} $xofSymbol';

  /// Valor exato com sinal explícito para entradas positivas.
  static String formatXofSigned(int amount) {
    if (amount > 0) {
      return '+${formatXof(amount)}';
    }
    return formatXof(amount);
  }

  /// Resumo compacto para cartões: exato abaixo de 1 milhão.
  ///
  /// `1 250 000` apresenta `1,25 M FCFA`; `1 250 000 000` apresenta
  /// `1,25 mil M FCFA` (mil milhões). O valor exato deve continuar disponível
  /// em textos de detalhe e na semântica de acessibilidade.
  static String formatXofCompact(int amount) {
    final absolute = amount.abs();
    if (absolute < compactThreshold) {
      return formatXof(amount);
    }
    final sign = amount < 0 ? '-' : '';
    if (absolute >= 1000000000) {
      return '$sign${_compact.format(absolute / 1000000000)} mil M $xofSymbol';
    }
    return '$sign${_compact.format(absolute / 1000000)} M $xofSymbol';
  }

  static String formatXofCompactSigned(int amount) {
    if (amount > 0) {
      return '+${formatXofCompact(amount)}';
    }
    return formatXofCompact(amount);
  }
}
