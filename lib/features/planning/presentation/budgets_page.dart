import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/formatters/money_input_parser.dart';
import '../../../core/widgets/empty_state.dart';
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Mês anterior',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () =>
                      ref.read(budgetMonthProvider.notifier).previous(),
                ),
                Expanded(
                  child: Text(
                    formatMonth(month),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
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
              AsyncData(:final value) when value.isEmpty => EmptyState(
                icon: Icons.pie_chart_outline,
                title: 'Sem orçamentos em ${formatMonth(month)}',
                message:
                    'Define um limite por categoria de despesa. '
                    'O gasto é calculado a partir dos movimentos reais.',
              ),
              AsyncData(:final value) => ListView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
                children: [
                  for (final budget in value)
                    _BudgetCard(
                      budget: budget,
                      onEditLimit: () => _editLimit(context, ref, budget),
                      onRemove: () => _remove(context, ref, budget),
                    ),
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
    final controller = TextEditingController(
      text: MoneyInputParser.formatPlain(budget.limitAmount),
    );
    String? error;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(budget.categoryName),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Limite mensal',
              suffixText: 'FCFA',
              border: const OutlineInputBorder(),
              errorText: error,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final limit = MoneyInputParser.parseXof(controller.text);
                if (limit == null) {
                  setState(
                    () => error = MoneyInputParser.validate(controller.text),
                  );
                  return;
                }
                Navigator.of(dialogContext).pop(true);
                _saveLimit(context, ref, budget, limit);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (saved != true) {
      return;
    }
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
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
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
            const SizedBox(height: 4),
            Text(
              '${MoneyFormatter.formatXof(budget.spent)} de '
              '${MoneyFormatter.formatXof(budget.limitAmount)} · '
              '${formatPercentage(budget.percent)}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: budget.progress,
                minHeight: 8,
                color: budget.isExceeded
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              budget.isExceeded
                  ? 'Excedido em '
                        '${MoneyFormatter.formatXof(-budget.remaining)}'
                  : 'Restam ${MoneyFormatter.formatXof(budget.remaining)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: budget.isExceeded ? theme.colorScheme.error : null,
              ),
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
