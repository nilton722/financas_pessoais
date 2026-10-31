import 'package:financas_pessoais/app/theme/app_theme.dart';
import 'package:financas_pessoais/core/formatters/money_formatter.dart';
import 'package:financas_pessoais/features/forecast/domain/forecast.dart';
import 'package:financas_pessoais/features/forecast/presentation/forecast_page.dart';
import 'package:financas_pessoais/features/forecast/presentation/forecast_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ForecastBundle _bundle() {
  final cutoff = DateTime(2026, 10, 30);
  final result = ForecastResult(
    cutoff: cutoff,
    endDate: cutoff.add(const Duration(days: 30)),
    openingBalance: 2500000,
    days: [
      for (var day = 0; day <= 30; day++)
        ForecastDay(
          date: cutoff.add(Duration(days: day)),
          openingBalance: 2500000 - day * 100000,
          confirmedDelta: 0,
          estimatedDelta: -100000,
          closingBalance: 2500000 - day * 100000,
        ),
    ],
    commitments: const [],
    closingBalance: -500000,
    lowestBalance: -7510000,
    lowestDate: cutoff.add(const Duration(days: 30)),
    confirmedNet: 0,
    estimatedNet: -3000000,
    quality: const ForecastDataQuality(
      historySufficient: false,
      monthsWithExpenses: 0,
      expenseMovements: 0,
      estimatedCategories: 0,
      estimatedMonthlyTotal: 0,
      limitations: [],
    ),
    assumptions: const [],
    parameters: const ForecastParameters(horizonDays: 30),
  );
  return ForecastBundle(
    cutoff: cutoff,
    generatedAt: DateTime.utc(2026, 10, 30, 12),
    results: {7: result, 30: result, 90: result},
  );
}

void main() {
  testWidgets('rodapé do gráfico cabe em ecrã estreito', (tester) async {
    tester.view.physicalSize = const Size(480, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [forecastBundleProvider.overrideWith((ref) => _bundle())],
        child: MaterialApp(theme: AppTheme.light, home: const ForecastPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Saldo dia a dia'), findsOneWidget);
    expect(
      find.textContaining('Máx. ${MoneyFormatter.formatXof(2500000)}'),
      findsOneWidget,
    );
  });
}
