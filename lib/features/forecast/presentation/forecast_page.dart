import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/finance_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/formatters/date_formatter.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/widgets/app_data_row.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/money_text.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/status_badge.dart';
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
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
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
          const SizedBox(height: AppSpacing.md),
          Text(
            'Data de corte: ${_formatDate(result.cutoff)} · '
            'Horizonte: ${result.horizonDays} dias',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          if (result.hasNegativeBalance) ...[
            _NegativeWarning(result: result),
            const SizedBox(height: AppSpacing.md),
          ],
          _ProjectionCard(result: result),
          const SizedBox(height: AppSpacing.md),
          _ForecastChart(result: result),
          const SizedBox(height: AppSpacing.md),
          _CommitmentsCard(result: result),
          const SizedBox(height: AppSpacing.md),
          _AssumptionsCard(result: result),
          const SizedBox(height: AppSpacing.md),
          _QualityCard(result: result),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: AppRadii.control,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cálculo: ${_formatTimestamp(bundle.generatedAt)} · '
                  'Algoritmo: $forecastAlgorithmVersion',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Estimativa local, não uma garantia. Não altera o saldo real.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
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
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_outlined, color: color),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Possível saldo negativo',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Mínimo previsto de '
                    '${MoneyFormatter.formatXof(result.lowestBalance)} '
                    'em ${_formatDate(result.lowestDate)}.',
                    style: theme.textTheme.bodySmall?.copyWith(color: color),
                  ),
                ],
              ),
            ),
          ],
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
    final negative = result.hasNegativeBalance;
    final color = negative
        ? theme.colorScheme.error
        : theme.colorScheme.primary;
    return SectionCard(
      title: 'Saldo projetado',
      leading: Icon(Icons.insights_outlined, color: color),
      subtitle:
          'em ${_formatDate(result.endDate)} · horizonte de '
          '${result.horizonDays} dias',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            MoneyFormatter.formatXof(result.closingBalance),
            key: const Key('forecastClosingBalance'),
            style: theme.textTheme.headlineMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          StatusBadge(
            negative ? 'Abaixo de zero' : 'Projeção estimada',
            tone: negative ? StatusTone.danger : StatusTone.info,
          ),
          const Divider(height: AppSpacing.xl),
          AppDataRow(
            label: 'Saldo de partida',
            value: MoneyText(result.openingBalance),
          ),
          AppDataRow(
            label: 'Compromissos confirmados',
            value: MoneyText(
              result.confirmedNet,
              signed: true,
              tone: result.confirmedNet < 0
                  ? MoneyTone.expense
                  : MoneyTone.income,
            ),
          ),
          if (result.quality.estimatedCategories > 0)
            AppDataRow(
              label: 'Despesas estimadas',
              value: MoneyText(
                result.estimatedNet,
                signed: true,
                tone: result.estimatedNet < 0
                    ? MoneyTone.expense
                    : MoneyTone.income,
              ),
            ),
          AppDataRow(
            label: 'Menor saldo previsto',
            emphasize: negative,
            value: MoneyText(
              result.lowestBalance,
              tone: negative ? MoneyTone.expense : MoneyTone.neutral,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          AppDataRow(
            label: 'Data do menor saldo',
            value: Text(
              _formatDate(result.lowestDate),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ForecastChart extends StatelessWidget {
  const _ForecastChart({required this.result});

  final ForecastResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final finance = FinanceColors.of(context);
    final days = result.days;
    final maximum = days.isEmpty
        ? result.closingBalance
        : days.map((day) => day.closingBalance).reduce((a, b) => a > b ? a : b);
    return SectionCard(
      title: 'Saldo dia a dia',
      subtitle: 'Valores no fim de cada dia · linha horizontal marca o zero',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 156,
            width: double.infinity,
            child: Semantics(
              label:
                  'Evolução diária do saldo previsto. '
                  'Máximo ${MoneyFormatter.formatXof(maximum)}, '
                  'mínimo ${MoneyFormatter.formatXof(result.lowestBalance)}.',
              child: CustomPaint(
                painter: _SparklinePainter(
                  days: days,
                  lineColor: result.hasNegativeBalance
                      ? theme.colorScheme.error
                      : finance.positive,
                  zeroColor: theme.colorScheme.outlineVariant,
                  fillColor:
                      (result.hasNegativeBalance
                              ? theme.colorScheme.error
                              : finance.positive)
                          .withValues(alpha: 0.12),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text(
                _formatDate(days.isEmpty ? result.cutoff : days.first.date),
                style: theme.textTheme.bodySmall,
              ),
              const Spacer(),
              Text(
                'Máx. ${MoneyFormatter.formatXof(maximum)} · '
                'Mín. ${MoneyFormatter.formatXof(result.lowestBalance)}',
                style: theme.textTheme.bodySmall,
              ),
              const Spacer(),
              Text(
                _formatDate(result.endDate),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ],
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
        ..strokeWidth = 2.5
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
    final finance = FinanceColors.of(context);
    return SectionCard(
      title: 'Próximos compromissos',
      subtitle: result.commitments.isEmpty
          ? 'Nenhum compromisso no horizonte'
          : '${result.commitments.length} no horizonte',
      padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: AppSpacing.xs),
      child: result.commitments.isEmpty
          ? const EmptyState(
              icon: Icons.event_available_outlined,
              title: 'Sem compromissos',
              message: 'Não existem compromissos abertos neste horizonte.',
            )
          : Column(
              children: [
                for (
                  var index = 0;
                  index < result.commitments.length;
                  index++
                ) ...[
                  if (index > 0) const Divider(height: 1),
                  _CommitmentRow(
                    line: result.commitments[index],
                    finance: finance,
                    theme: theme,
                  ),
                ],
              ],
            ),
    );
  }
}

class _CommitmentRow extends StatelessWidget {
  const _CommitmentRow({
    required this.line,
    required this.finance,
    required this.theme,
  });

  final ForecastMovementLine line;
  final FinanceColors finance;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: line.isInflow
              ? finance.incomeContainer
              : theme.colorScheme.errorContainer,
          borderRadius: AppRadii.badge,
        ),
        child: Icon(
          line.isInflow ? Icons.south_west : Icons.north_east,
          size: 17,
          color: line.isInflow
              ? finance.onIncomeContainer
              : theme.colorScheme.onErrorContainer,
        ),
      ),
      title: Text(line.description),
      subtitle: Text(
        [
          _formatDate(line.date),
          if (line.categoryName != null) line.categoryName!,
        ].join(' · '),
      ),
      trailing: MoneyText(
        line.amount,
        signed: true,
        tone: line.isInflow ? MoneyTone.income : MoneyTone.expense,
        style: theme.textTheme.titleSmall,
      ),
    );
  }
}

class _AssumptionsCard extends StatelessWidget {
  const _AssumptionsCard({required this.result});

  final ForecastResult result;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Pressupostos',
      leading: Icon(
        Icons.info_outline,
        color: Theme.of(context).colorScheme.primary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final assumption in result.assumptions)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _Bullet(text: assumption),
            ),
        ],
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
    return SectionCard(
      title: 'Qualidade dos dados e limitações',
      leading: Icon(
        quality.historySufficient
            ? Icons.fact_check_outlined
            : Icons.rule_outlined,
        color: quality.historySufficient
            ? theme.colorScheme.primary
            : FinanceColors.of(context).warning,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(quality.summary, style: theme.textTheme.bodyMedium),
          if (quality.limitations.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            for (final limitation in quality.limitations)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: _Bullet(text: limitation, muted: true),
              ),
          ],
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text, this.muted = false});

  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outline,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: muted
                ? theme.textTheme.bodySmall
                : theme.textTheme.bodyMedium,
          ),
        ),
      ],
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
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
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
