import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/widgets/empty_state.dart';
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
          padding: const EdgeInsets.all(16),
          children: [
            _PeriodCard(
              filter: filter,
              onPreset: (preset) => _selectPreset(preset, filter.period),
              onPickRange: () => _pickRange(filter.period),
            ),
            const SizedBox(height: 12),
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
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            },
            const SizedBox(height: 16),
            Text(
              'Transferências entre contas próprias aparecem à parte e não '
              'alteram rendimentos, despesas nem o resultado.',
              style: theme.textTheme.bodySmall,
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
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
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
                  const SizedBox(height: 4),
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
          padding: EdgeInsets.all(16),
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
        const SizedBox(height: 12),
        Card(
          key: const Key('report-groups'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<ReportGroupMode>(
                  segments: [
                    for (final item in ReportGroupMode.values)
                      ButtonSegment(value: item, label: Text(item.label)),
                  ],
                  selected: {mode},
                  showSelectedIcon: false,
                  onSelectionChanged: (selected) => onMode(selected.first),
                ),
                const SizedBox(height: 12),
                for (final group in groups)
                  _GroupRow(group: group, maxVolume: maxVolume),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const Key('report-export'),
          onPressed: onExport,
          icon: const Icon(Icons.download_outlined),
          label: const Text('Exportar CSV'),
        ),
        if (onExport == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Não há movimentos para exportar neste período.',
              style: Theme.of(context).textTheme.bodySmall,
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
    final netColor = summary.net < 0
        ? theme.colorScheme.error
        : theme.colorScheme.primary;
    return Card(
      key: const Key('report-summary'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resumo do período', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _SummaryValue(
                    label: 'Rendimentos',
                    amount: summary.income,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Expanded(
                  child: _SummaryValue(
                    label: 'Despesas',
                    amount: summary.expense,
                    color: theme.colorScheme.error,
                  ),
                ),
                Expanded(
                  child: _SummaryValue(
                    label: 'Resultado',
                    amount: summary.net,
                    color: netColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${summary.movementCount} movimento(s)'
              '${summary.transferTotal > 0 ? ' · Transferências '
                        '${MoneyFormatter.formatXof(summary.transferTotal)} '
                        '(fora do resultado)' : ''}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          MoneyFormatter.formatXof(amount),
          style: theme.textTheme.titleSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
    final fraction = maxVolume <= 0 ? 0.0 : group.volume / maxVolume;
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
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(group.label, style: theme.textTheme.bodyLarge),
                  ),
                  Text(
                    MoneyFormatter.formatXof(group.net),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: group.net < 0
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 8,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Rend. ${MoneyFormatter.formatXof(group.income)} · '
                'Desp. ${MoneyFormatter.formatXof(group.expense)}$transfers',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
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
