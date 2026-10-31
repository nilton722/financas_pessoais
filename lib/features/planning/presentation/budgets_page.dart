import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/formatters/money_input_parser.dart';
import '../../../core/widgets/app_data_row.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/money_text.dart';
import '../../../core/widgets/status_badge.dart';
import '../domain/budget.dart';
import 'planning_format.dart';
import 'planning_providers.dart';

class BudgetsPage extends ConsumerWidget {
  const BudgetsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(budgetMonthProvider);
    final budgets = ref.watch(budgetsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orçamentos'),
        actions: [
          IconButton(
            tooltip: 'Mês atual',
            icon: const Icon(Icons.today_outlined),
            onPressed: () =>
                ref.read(budgetMonthProvider.notifier).setMonth(DateTime.now()),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/planning/budgets/new'),
        icon: const Icon(Icons.add),
        label: const Text('Novo orçamento'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Mês anterior',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () =>
                      ref.read(budgetMonthProvider.notifier).previous(),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text('Orçamentos de', style: theme.textTheme.labelSmall),
                      Text(
                        formatMonth(month),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Mês seguinte',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () =>
                      ref.read(budgetMonthProvider.notifier).next(),
                ),
              ],
            ),
          ),
          Expanded(
            child: switch (budgets) {
              AsyncData(:final value) when value.isEmpty => Center(
                child: SingleChildScrollView(
                  padding: AppSpacing.page,
                  child: EmptyState(
                    icon: Icons.pie_chart_outline,
                    title: 'Sem orçamentos em ${formatMonth(month)}',
                    message:
                        'Define um limite por categoria de despesa. '
                        'O gasto é calculado a partir dos movimentos reais.',
                    action: FilledButton.icon(
                      onPressed: () => context.push('/planning/budgets/new'),
                      icon: const Icon(Icons.add),
                      label: const Text('Novo orçamento'),
                    ),
                  ),
                ),
              ),
              AsyncData(:final value) => ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.xxl + AppSpacing.xxxl,
                ),
                children: [
                  for (final budget in value) ...[
                    _BudgetCard(
                      budget: budget,
                      onEditLimit: () => _editLimit(context, ref, budget),
                      onRemove: () => _remove(context, ref, budget),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ],
              ),
              AsyncError(:final error) => _ErrorView(
                error: error,
                onRetry: () => ref.invalidate(budgetsProvider),
              ),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
        ],
      ),
    );
  }

  Future<void> _editLimit(
    BuildContext context,
    WidgetRef ref,
    Budget budget,
  ) async {
    final limit = await showDialog<int>(
      context: context,
      builder: (dialogContext) => _LimitDialog(
        categoryName: budget.categoryName,
        initialLimit: budget.limitAmount,
      ),
    );
    if (limit == null || !context.mounted) {
      return;
    }
    await _saveLimit(context, ref, budget, limit);
  }

  Future<void> _saveLimit(
    BuildContext context,
    WidgetRef ref,
    Budget budget,
    int limit,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(budgetRepositoryProvider)
          .save(
            BudgetDraft(
              categoryId: budget.categoryId,
              limitAmount: limit,
              periodStart: budget.periodStart,
            ),
          );
      messenger.showSnackBar(
        const SnackBar(content: Text('Limite atualizado.')),
      );
    } on AppFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    Budget budget,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remover orçamento?'),
        content: Text(
          'O limite de «${budget.categoryName}» em '
          '${formatMonth(budget.periodStart)} deixa de ser acompanhado. '
          'Os movimentos não são alterados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(budgetRepositoryProvider).remove(budget.id);
      messenger.showSnackBar(
        const SnackBar(content: Text('Orçamento removido.')),
      );
    } on AppFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }
}

class _LimitDialog extends StatefulWidget {
  const _LimitDialog({required this.categoryName, required this.initialLimit});

  final String categoryName;
  final int initialLimit;

  @override
  State<_LimitDialog> createState() => _LimitDialogState();
}

class _LimitDialogState extends State<_LimitDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: MoneyInputParser.formatPlain(widget.initialLimit),
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final limit = MoneyInputParser.parseXof(_controller.text);
    if (limit == null) {
      setState(() => _error = MoneyInputParser.validate(_controller.text));
      return;
    }
    Navigator.of(context).pop(limit);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.categoryName),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: 'Limite mensal',
          suffixText: 'FCFA',
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Guardar')),
      ],
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.budget,
    required this.onEditLimit,
    required this.onRemove,
  });

  final Budget budget;
  final VoidCallback onEditLimit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = budget.isExceeded ? StatusTone.danger : StatusTone.neutral;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    budget.categoryName,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                StatusBadge(formatPercentage(budget.percent), tone: tone),
                PopupMenuButton<String>(
                  tooltip: 'Opções',
                  onSelected: (value) {
                    if (value == 'limit') {
                      onEditLimit();
                    } else {
                      onRemove();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'limit',
                      child: Text('Alterar limite'),
                    ),
                    PopupMenuItem(value: 'remove', child: Text('Remover')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            AppDataRow(
              label: 'Gasto',
              value: MoneyText(
                budget.spent,
                style: theme.textTheme.bodyMedium,
                maxLines: 1,
              ),
            ),
            AppDataRow(
              label: 'Limite',
              value: MoneyText(
                budget.limitAmount,
                style: theme.textTheme.bodyMedium,
                maxLines: 1,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            ClipRRect(
              borderRadius: AppRadii.small,
              child: LinearProgressIndicator(
                value: budget.progress,
                minHeight: 8,
                color: budget.isExceeded
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(
                  budget.isExceeded
                      ? Icons.error_outline
                      : Icons.check_circle_outline,
                  size: 16,
                  color: budget.isExceeded
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  budget.isExceeded ? 'Excedido em' : 'Restam',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(width: AppSpacing.xs),
                MoneyText(
                  budget.isExceeded ? -budget.remaining : budget.remaining,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  tone: budget.isExceeded
                      ? MoneyTone.expense
                      : MoneyTone.income,
                  maxLines: 1,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error is AppFailure
        ? (error as AppFailure).message
        : 'Não foi possível carregar os orçamentos.';
    return Center(
      child: Padding(
        padding: AppSpacing.page,
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
