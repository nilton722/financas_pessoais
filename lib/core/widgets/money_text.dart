import 'package:flutter/material.dart';

import '../../app/theme/finance_colors.dart';
import '../formatters/money_formatter.dart';

/// Significado visual de um montante. A cor nunca é o único indicador:
/// o sinal e a etiqueta textual acompanham o valor.
enum MoneyTone { neutral, income, expense, transfer, projection, warning }

/// Montante com algarismos tabulares, alinhamento à direita e sinal opcional.
///
/// Em resumos (`compact: true`) o texto pode ser abreviado, mas a semântica
/// continua a anunciar o valor exato em FCFA.
class MoneyText extends StatelessWidget {
  const MoneyText(
    this.amount, {
    super.key,
    this.style,
    this.tone = MoneyTone.neutral,
    this.signed = false,
    this.compact = false,
    this.semanticsLabel,
    this.textAlign = TextAlign.end,
    this.maxLines = 1,
  });

  final int amount;
  final TextStyle? style;
  final MoneyTone tone;
  final bool signed;
  final bool compact;
  final String? semanticsLabel;
  final TextAlign textAlign;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final finance = FinanceColors.of(context);
    final exact = signed
        ? MoneyFormatter.formatXofSigned(amount)
        : MoneyFormatter.formatXof(amount);
    final display = compact
        ? (signed
              ? MoneyFormatter.formatXofCompactSigned(amount)
              : MoneyFormatter.formatXofCompact(amount))
        : exact;
    final baseStyle = style ?? theme.textTheme.bodyLarge;
    final color = switch (tone) {
      MoneyTone.neutral => null,
      MoneyTone.income => finance.income,
      MoneyTone.expense => theme.colorScheme.error,
      MoneyTone.transfer => finance.transfer,
      MoneyTone.projection => theme.colorScheme.primary,
      MoneyTone.warning => finance.warning,
    };
    final effectiveStyle = baseStyle?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
      color: color ?? baseStyle.color,
    );
    final text = Text(
      display,
      style: effectiveStyle,
      textAlign: textAlign,
      maxLines: maxLines,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
    );
    if (!compact && semanticsLabel == null) {
      return text;
    }
    return Semantics(
      label: semanticsLabel ?? exact,
      child: ExcludeSemantics(child: text),
    );
  }
}
