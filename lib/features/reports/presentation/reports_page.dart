import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/finance_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/formatters/plural_formatter.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/money_text.dart';
import '../../../core/widgets/section_card.dart';
import '../domain/report.dart';
import 'reports_providers.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filter = ref.watch(reportFilterProvider);
    final mode = ref.watch(reportGroupModeProvider);
    final data = ref.watch(reportDataProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Relatórios')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(reportDataProvider),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          children: [
            _PeriodCard(
              filter: filter,
              onPreset: (preset) => _selectPreset(preset, filter.period),
              onPickRange: () => _pickRange(filter.period),
            ),
            const SizedBox(height: AppSpacing.md),
            switch (data) {
              AsyncData(:final value) => _ReportBody(
                data: value,
                mode: mode,
                onMode: (selected) =>
                    ref.read(reportGroupModeProvider.notifier).select(selected),
                onExport: value.summary.isEmpty || _exporting
                    ? null
                    : () => _export(value),
              ),
              AsyncError(:final error) => _ErrorCard(
                error: error,
                onRetry: () => ref.invalidate(reportDataProvider),
              ),
              _ => const Padding(
                padding: EdgeInsets.all(AppSpacing.xxl),
                child: Center(child: CircularProgressIndicator()),
              ),
            },
            const SizedBox(height: AppSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Transferências entre contas próprias aparecem à parte e '
                    'não alteram rendimentos, despesas nem o resultado.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectPreset(ReportPreset preset, ReportPeriod current) async {
    if (preset == ReportPreset.custom) {
      await _pickRange(current);
      return;
    }
    ref.read(reportFilterProvider.notifier).setPreset(preset);
  }

  Future<void> _pickRange(ReportPeriod current) async {
    final today = DateTime.now();
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(today.year, today.month, today.day),
      initialDateRange: DateTimeRange(
        start: current.from,
        end: current.to.isAfter(today) ? today : current.to,
      ),
      helpText: 'Período do relatório',
      saveText: 'Aplicar',
    );
    if (selected != null) {
      ref
          .read(reportFilterProvider.notifier)
          .setRange(selected.start, selected.end);
    }
  }

  Future<void> _export(ReportData data) async {
    setState(() => _exporting = true);
    try {
      final period = ref.read(reportFilterProvider).period;
      final file = await ref
          .read(reportExportServiceProvider)
          .export(from: period.from, to: period.to, items: data.items);
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Relatório exportado: ${file.path}'),
          action: SnackBarAction(
            label: 'Copiar caminho',
            onPressed: () => Clipboard.setData(ClipboardData(text: file.path)),
          ),
        ),
      );
    } on AppFailure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(failure.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }
}

class _PeriodCard extends StatelessWidget {
  const _PeriodCard({
    required this.filter,
    required this.onPreset,
    required this.onPickRange,
  });

  final ReportFilter filter;
  final ValueChanged<ReportPreset> onPreset;
  final VoidCallback onPickRange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButton<ReportPreset>(
                    value: filter.preset,
                    isDense: true,
                    underline: const SizedBox.shrink(),
                    style: theme.textTheme.titleMedium,
                    onChanged: (preset) {
                      if (preset != null) {
                        onPreset(preset);
                      }
                    },
                    items: [
                      for (final preset in ReportPreset.values)
                        DropdownMenuItem(
                          value: preset,
                          child: Text(preset.label),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(filter.period.label, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Escolher datas',
              icon: const Icon(Icons.date_range_outlined),
              onPressed: onPickRange,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({
    required this.data,
    required this.mode,
    required this.onMode,
    required this.onExport,
  });

  final ReportData data;
  final ReportGroupMode mode;
  final ValueChanged<ReportGroupMode> onMode;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    final summary = data.summary;
    if (summary.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: EmptyState(
            icon: Icons.query_stats_outlined,
            title: 'Sem movimentos no período',
            message:
                'Escolha outro período ou registe movimentos para ver o '
                'resumo por categoria e conta.',
          ),
        ),
      );
    }

    final groups = mode == ReportGroupMode.category
        ? summary.categories
        : summary.accounts;
    final maxVolume = groups.fold<int>(
      0,
      (highest, group) => group.volume > highest ? group.volume : highest,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryCard(summary: summary),
        const SizedBox(height: AppSpacing.md),
        SectionCard(
          key: const Key('report-groups'),
          title: 'Detalhe',
          subtitle:
              'Agrupado por '
              '${mode == ReportGroupMode.category ? 'categoria' : 'conta'}',
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: SegmentedButton<ReportGroupMode>(
                  segments: [
                    for (final item in ReportGroupMode.values)
                      ButtonSegment(
                        value: item,
                        label: Text(item.label),
                        icon: Icon(
                          item == ReportGroupMode.category
                              ? Icons.category_outlined
                              : Icons.account_balance_wallet_outlined,
                          size: 16,
                        ),
                      ),
                  ],
                  selected: {mode},
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onSelectionChanged: (selected) => onMode(selected.first),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (var index = 0; index < groups.length; index++) ...[
                if (index > 0) const Divider(height: 1),
                _GroupRow(group: groups[index], maxVolume: maxVolume),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          key: const Key('report-export'),
          onPressed: onExport,
          icon: const Icon(Icons.download_outlined),
          label: const Text('Exportar CSV'),
        ),
        if (onExport == null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              'Não há movimentos para exportar neste período.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final ReportSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final finance = FinanceColors.of(context);
    final netColor = summary.net < 0
        ? theme.colorScheme.error
        : finance.positive;
    return SectionCard(
      key: const Key('report-summary'),
      title: 'Resumo do período',
      subtitle: 'Movimentos confirmados, sem transferências entre contas',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SummaryValue(
                  label: 'Rendimentos',
                  amount: summary.income,
                  color: finance.income,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _SummaryValue(
                  label: 'Despesas',
                  amount: summary.expense,
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _SummaryValue(
                  label: 'Resultado',
                  amount: summary.net,
                  color: netColor,
                  emphasized: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _MetaPill(
                icon: Icons.receipt_long_outlined,
                label: PluralFormatter.count(
                  summary.movementCount,
                  'movimento',
                  'movimentos',
                ),
              ),
              if (summary.transferTotal > 0)
                _MetaPill(
                  icon: Icons.swap_horiz,
                  label:
                      'Transferências '
                      '${MoneyFormatter.formatXof(summary.transferTotal)}',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({
    required this.label,
    required this.amount,
    required this.color,
    this.emphasized = false,
  });

  final String label;
  final int amount;
  final Color color;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelSmall),
        const SizedBox(height: AppSpacing.xs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: MoneyText(
            amount,
            semanticsLabel: '$label: ${MoneyFormatter.formatXof(amount)}',
            style:
                (emphasized
                        ? theme.textTheme.titleMedium
                        : theme.textTheme.titleSmall)
                    ?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: AppRadii.badge,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.xs),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({required this.group, required this.maxVolume});

  final ReportGroup group;
  final int maxVolume;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final finance = FinanceColors.of(context);
    final enabled = group.volume > 0;
    final fraction = !enabled
        ? 0.0
        : maxVolume <= 0
        ? 0.0
        : (group.volume / maxVolume).clamp(0.0, 1.0);
    final transfers = group.transfers > 0
        ? ' · Transferências ${MoneyFormatter.formatXof(group.transfers)}'
        : '';
    final description =
        '${group.label}: rendimento ${MoneyFormatter.formatXof(group.income)}, '
        'despesa ${MoneyFormatter.formatXof(group.expense)}, '
        'resultado ${MoneyFormatter.formatXof(group.net)}$transfers. '
        'Barra proporcional ao volume movimentado.';
    return Semantics(
      container: true,
      label: description,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      group.label,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  MoneyText(
                    group.net,
                    tone: group.net < 0 ? MoneyTone.expense : MoneyTone.income,
                    style: theme.textTheme.titleSmall,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: AppRadii.small,
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 7,
                  backgroundColor: theme.colorScheme.surfaceContainerHigh,
                  color: group.net < 0
                      ? theme.colorScheme.error
                      : finance.transfer,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.xxs,
                children: [
                  _MiniValue(
                    label: 'Rend.',
                    amount: group.income,
                    color: finance.income,
                  ),
                  _MiniValue(
                    label: 'Desp.',
                    amount: group.expense,
                    color: theme.colorScheme.error,
                  ),
                  if (group.transfers > 0)
                    _MiniValue(
                      label: 'Transf.',
                      amount: group.transfers,
                      color: finance.transfer,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniValue extends StatelessWidget {
  const _MiniValue({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final int amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ', style: theme.textTheme.bodySmall),
        MoneyText(
          amount,
          style: theme.textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error is AppFailure
        ? (error as AppFailure).message
        : 'Não foi possível calcular o relatório.';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
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
