import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/formatters/date_formatter.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/widgets/empty_state.dart';
import '../domain/forecast.dart';
import 'forecast_providers.dart';

class ForecastPage extends ConsumerStatefulWidget {
  const ForecastPage({super.key});

  @override
  ConsumerState<ForecastPage> createState() => _ForecastPageState();
}

class _ForecastPageState extends ConsumerState<ForecastPage> {
  int _horizon = 30;

  Future<void> _refresh() async {
    ref.invalidate(forecastBundleProvider);
    await ref.read(forecastBundleProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final bundle = ref.watch(forecastBundleProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Previsão'),
        actions: [
          IconButton(
            tooltip: 'Recalcular previsão',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: switch (bundle) {
        AsyncData(:final value) => _ForecastContent(
          bundle: value,
          horizon: _horizon,
          onHorizonChanged: (horizon) => setState(() => _horizon = horizon),
          onRefresh: _refresh,
        ),
        AsyncError(:final error) => _ForecastFailure(
          error: error,
          onRetry: _refresh,
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _ForecastContent extends StatelessWidget {
  const _ForecastContent({
    required this.bundle,
    required this.horizon,
    required this.onHorizonChanged,
    required this.onRefresh,
  });

  final ForecastBundle bundle;
  final int horizon;
  final ValueChanged<int> onHorizonChanged;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = bundle.resultFor(horizon);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<int>(
            segments: [
              for (final value in forecastHorizons)
                ButtonSegment(value: value, label: Text('$value dias')),
            ],
            selected: {horizon},
            showSelectedIcon: false,
            onSelectionChanged: (selection) =>
                onHorizonChanged(selection.first),
          ),
          const SizedBox(height: 12),
          if (result.hasNegativeBalance) ...[
            _NegativeWarning(result: result),
            const SizedBox(height: 12),
          ],
          _ProjectionCard(result: result),
          const SizedBox(height: 12),
          _ForecastChart(days: result.days),
          const SizedBox(height: 12),
          _CommitmentsCard(result: result),
          const SizedBox(height: 12),
          _AssumptionsCard(result: result),
          const SizedBox(height: 12),
          _QualityCard(result: result),
          const SizedBox(height: 16),
          Text(
            'Data de corte: ${_formatDate(result.cutoff)} · '
            'Cálculo: ${_formatTimestamp(bundle.generatedAt)} · '
            'Algoritmo: $forecastAlgorithmVersion · '
            'Horizonte: ${result.horizonDays} dias',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _NegativeWarning extends StatelessWidget {
  const _NegativeWarning({required this.result});

  final ForecastResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onErrorContainer;
    return Card(
      color: theme.colorScheme.errorContainer,
      child: ListTile(
        leading: Icon(Icons.warning_amber_outlined, color: color),
        title: Text(
          'Possível saldo negativo',
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Mínimo previsto de ${MoneyFormatter.formatXof(result.lowestBalance)} '
          'em ${_formatDate(result.lowestDate)}.',
          style: TextStyle(color: color),
        ),
      ),
    );
  }
}

class _ProjectionCard extends StatelessWidget {
  const _ProjectionCard({required this.result});

  final ForecastResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = result.hasNegativeBalance
        ? theme.colorScheme.error
        : theme.colorScheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights_outlined, color: color),
                const SizedBox(width: 8),
                Text('Saldo projetado', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              MoneyFormatter.formatXof(result.closingBalance),
              key: const Key('forecastClosingBalance'),
              style: theme.textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'em ${_formatDate(result.endDate)} · horizonte de '
              '${result.horizonDays} dias',
              style: theme.textTheme.bodySmall,
            ),
            const Divider(height: 24),
            _MetricRow(
              label: 'Saldo de partida',
              value: MoneyFormatter.formatXof(result.openingBalance),
            ),
            _MetricRow(
              label: 'Compromissos confirmados',
              value: _signedMoney(result.confirmedNet),
            ),
            if (result.quality.estimatedCategories > 0)
              _MetricRow(
                label: 'Despesas estimadas',
                value: _signedMoney(result.estimatedNet),
              ),
            _MetricRow(
              label: 'Menor saldo previsto',
              value:
                  '${MoneyFormatter.formatXof(result.lowestBalance)} · '
                  '${_formatDate(result.lowestDate)}',
              emphasize: result.hasNegativeBalance,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodySmall)),
          const SizedBox(width: 12),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
              color: emphasize ? theme.colorScheme.error : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _ForecastChart extends StatelessWidget {
  const _ForecastChart({required this.days});

  final List<ForecastDay> days;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Saldo dia a dia', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SizedBox(
              height: 140,
              width: double.infinity,
              child: Semantics(
                label: 'Evolução diária do saldo previsto',
                child: CustomPaint(
                  painter: _SparklinePainter(
                    days: days,
                    lineColor: theme.colorScheme.primary,
                    zeroColor: theme.colorScheme.outlineVariant,
                    fillColor: theme.colorScheme.primary.withValues(
                      alpha: 0.12,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'A linha horizontal marca o zero; a curva usa o saldo no fim '
              'de cada dia.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.days,
    required this.lineColor,
    required this.zeroColor,
    required this.fillColor,
  });

  final List<ForecastDay> days;
  final Color lineColor;
  final Color zeroColor;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (days.length < 2 || size.width <= 0 || size.height <= 0) {
      return;
    }
    var minimum = days.first.closingBalance;
    var maximum = minimum;
    for (final day in days) {
      if (day.closingBalance < minimum) {
        minimum = day.closingBalance;
      }
      if (day.closingBalance > maximum) {
        maximum = day.closingBalance;
      }
    }
    if (minimum > 0) {
      minimum = 0;
    }
    if (maximum < 0) {
      maximum = 0;
    }
    final range = maximum == minimum ? 1 : maximum - minimum;
    double x(int index) => size.width * index / (days.length - 1);
    double y(int value) =>
        size.height - (value - minimum) / range * size.height;

    final zeroY = y(0);
    canvas.drawLine(
      Offset(0, zeroY),
      Offset(size.width, zeroY),
      Paint()
        ..color = zeroColor
        ..strokeWidth = 1,
    );

    final fill = Path()..moveTo(x(0), y(days.first.closingBalance));
    for (var index = 1; index < days.length; index++) {
      fill.lineTo(x(index), y(days[index].closingBalance));
    }
    fill
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fill, Paint()..color = fillColor);

    final line = Path()..moveTo(x(0), y(days.first.closingBalance));
    for (var index = 1; index < days.length; index++) {
      line.lineTo(x(index), y(days[index].closingBalance));
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = lineColor
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.days != days ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.zeroColor != zeroColor ||
      oldDelegate.fillColor != fillColor;
}

class _CommitmentsCard extends StatelessWidget {
  const _CommitmentsCard({required this.result});

  final ForecastResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Próximos compromissos',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text(
                  '${result.commitments.length} no horizonte',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (result.commitments.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: EmptyState(
                icon: Icons.event_available_outlined,
                title: 'Sem compromissos',
                message: 'Não existem compromissos abertos neste horizonte.',
              ),
            )
          else
            for (final line in result.commitments)
              ListTile(
                dense: true,
                leading: Icon(
                  line.isInflow ? Icons.south_west : Icons.north_east,
                  color: line.isInflow
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                ),
                title: Text(line.description),
                subtitle: Text(
                  [
                    _formatDate(line.date),
                    if (line.categoryName != null) line.categoryName!,
                  ].join(' · '),
                ),
                trailing: Text(
                  _signedMoney(line.amount),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: line.isInflow
                        ? theme.colorScheme.primary
                        : theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _AssumptionsCard extends StatelessWidget {
  const _AssumptionsCard({required this.result});

  final ForecastResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Pressupostos', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            for (final assumption in result.assumptions)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $assumption', style: theme.textTheme.bodySmall),
              ),
          ],
        ),
      ),
    );
  }
}

class _QualityCard extends StatelessWidget {
  const _QualityCard({required this.result});

  final ForecastResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quality = result.quality;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  quality.historySufficient
                      ? Icons.fact_check_outlined
                      : Icons.rule_outlined,
                  color: quality.historySufficient
                      ? theme.colorScheme.primary
                      : theme.colorScheme.tertiary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Qualidade dos dados e limitações',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(quality.summary, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            for (final limitation in quality.limitations)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $limitation', style: theme.textTheme.bodySmall),
              ),
          ],
        ),
      ),
    );
  }
}

class _ForecastFailure extends StatelessWidget {
  const _ForecastFailure({required this.error, required this.onRetry});

  final Object error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error is AppFailure
        ? (error as AppFailure).message
        : 'Não foi possível calcular a previsão com os dados locais.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) =>
    FinancialDate.toDisplay(FinancialDate.fromDateTime(date));

String _formatTimestamp(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${_formatDate(local)} $hour:$minute';
}

String _signedMoney(int amount) {
  if (amount > 0) {
    return '+${MoneyFormatter.formatXof(amount)}';
  }
  return MoneyFormatter.formatXof(amount);
}
