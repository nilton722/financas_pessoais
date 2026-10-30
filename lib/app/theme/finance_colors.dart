import 'package:flutter/material.dart';

/// Cores com significado financeiro, independentes do esquema tonal Material.
///
/// Despesa continua a usar `colorScheme.error`; rendimento, transferência e
/// aviso têm valores próprios com contraste suficiente em claro e escuro.
@immutable
class FinanceColors extends ThemeExtension<FinanceColors> {
  const FinanceColors({
    required this.income,
    required this.incomeContainer,
    required this.onIncomeContainer,
    required this.transfer,
    required this.transferContainer,
    required this.onTransferContainer,
    required this.warning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.positive,
    required this.positiveContainer,
    required this.onPositiveContainer,
  });

  final Color income;
  final Color incomeContainer;
  final Color onIncomeContainer;
  final Color transfer;
  final Color transferContainer;
  final Color onTransferContainer;
  final Color warning;
  final Color warningContainer;
  final Color onWarningContainer;

  /// Saldo acima de zero em resumos; distinto do verde de rendimento.
  final Color positive;
  final Color positiveContainer;
  final Color onPositiveContainer;

  static const FinanceColors light = FinanceColors(
    income: Color(0xFF1B6E45),
    incomeContainer: Color(0xFFD6F2E0),
    onIncomeContainer: Color(0xFF063A22),
    transfer: Color(0xFF175E8C),
    transferContainer: Color(0xFFD6EAF7),
    onTransferContainer: Color(0xFF0A334F),
    warning: Color(0xFF8A5A00),
    warningContainer: Color(0xFFFFE6B5),
    onWarningContainer: Color(0xFF2E1D00),
    positive: Color(0xFF0F5C4A),
    positiveContainer: Color(0xFFB8E8DB),
    onPositiveContainer: Color(0xFF00201A),
  );

  static const FinanceColors dark = FinanceColors(
    income: Color(0xFF7DD8A6),
    incomeContainer: Color(0xFF123D2A),
    onIncomeContainer: Color(0xFFB7F2CD),
    transfer: Color(0xFF8CCBF5),
    transferContainer: Color(0xFF12364D),
    onTransferContainer: Color(0xFFCDE9FB),
    warning: Color(0xFFF2C66D),
    warningContainer: Color(0xFF4A3600),
    onWarningContainer: Color(0xFFFFE6A8),
    positive: Color(0xFF80D8C4),
    positiveContainer: Color(0xFF0C3A31),
    onPositiveContainer: Color(0xFFB9F0E3),
  );

  static FinanceColors of(BuildContext context) =>
      Theme.of(context).extension<FinanceColors>() ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);

  @override
  FinanceColors copyWith({
    Color? income,
    Color? incomeContainer,
    Color? onIncomeContainer,
    Color? transfer,
    Color? transferContainer,
    Color? onTransferContainer,
    Color? warning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? positive,
    Color? positiveContainer,
    Color? onPositiveContainer,
  }) => FinanceColors(
    income: income ?? this.income,
    incomeContainer: incomeContainer ?? this.incomeContainer,
    onIncomeContainer: onIncomeContainer ?? this.onIncomeContainer,
    transfer: transfer ?? this.transfer,
    transferContainer: transferContainer ?? this.transferContainer,
    onTransferContainer: onTransferContainer ?? this.onTransferContainer,
    warning: warning ?? this.warning,
    warningContainer: warningContainer ?? this.warningContainer,
    onWarningContainer: onWarningContainer ?? this.onWarningContainer,
    positive: positive ?? this.positive,
    positiveContainer: positiveContainer ?? this.positiveContainer,
    onPositiveContainer: onPositiveContainer ?? this.onPositiveContainer,
  );

  @override
  FinanceColors lerp(ThemeExtension<FinanceColors>? other, double t) {
    if (other is! FinanceColors) {
      return this;
    }
    return FinanceColors(
      income: Color.lerp(income, other.income, t)!,
      incomeContainer: Color.lerp(incomeContainer, other.incomeContainer, t)!,
      onIncomeContainer: Color.lerp(
        onIncomeContainer,
        other.onIncomeContainer,
        t,
      )!,
      transfer: Color.lerp(transfer, other.transfer, t)!,
      transferContainer: Color.lerp(
        transferContainer,
        other.transferContainer,
        t,
      )!,
      onTransferContainer: Color.lerp(
        onTransferContainer,
        other.onTransferContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      onWarningContainer: Color.lerp(
        onWarningContainer,
        other.onWarningContainer,
        t,
      )!,
      positive: Color.lerp(positive, other.positive, t)!,
      positiveContainer: Color.lerp(
        positiveContainer,
        other.positiveContainer,
        t,
      )!,
      onPositiveContainer: Color.lerp(
        onPositiveContainer,
        other.onPositiveContainer,
        t,
      )!,
    );
  }
}
