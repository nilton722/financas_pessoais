import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/app_data_row.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/money_text.dart';
import '../../../core/widgets/status_badge.dart';
import '../domain/savings_goal.dart';
import 'planning_format.dart';
import 'planning_providers.dart';

class SavingsGoalsPage extends ConsumerWidget {
  const SavingsGoalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(savingsGoalsProvider);
    final showArchived = ref.watch(showArchivedGoalsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Metas de poupança'),
        actions: [
          IconButton(
            tooltip: showArchived ? 'Ocultar arquivadas' : 'Mostrar arquivadas',
            icon: Icon(
              showArchived
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
            onPressed: () =>
                ref.read(showArchivedGoalsProvider.notifier).toggle(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/planning/goals/new'),
        icon: const Icon(Icons.add),
        label: const Text('Nova meta'),
      ),
      body: switch (goals) {
        AsyncData(:final value) when value.isEmpty => Center(
          child: SingleChildScrollView(
            padding: AppSpacing.page,
            child: EmptyState(
              icon: Icons.savings_outlined,
              title: 'Sem metas',
              message:
                  'Define um alvo e associa uma conta de poupança para '
                  'acompanhar o progresso a partir do saldo real.',
              action: FilledButton.icon(
                onPressed: () => context.push('/planning/goals/new'),
                icon: const Icon(Icons.add),
                label: const Text('Nova meta'),
              ),
            ),
          ),
        ),
        AsyncData(:final value) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xxl + AppSpacing.xxxl,
          ),
          itemCount: value.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final goal = value[index];
            return Card(
              clipBehavior: Clip.antiAlias,
              child: _GoalCard(
                goal: goal,
                onEdit: () => context.push('/planning/goals/${goal.id}/edit'),
                onToggleArchive: () => _toggleArchive(context, ref, goal),
              ),
            );
          },
        ),
        AsyncError(:final error) => _ErrorView(
          error: error,
          onRetry: () => ref.invalidate(savingsGoalsProvider),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Future<void> _toggleArchive(
    BuildContext context,
    WidgetRef ref,
    SavingsGoal goal,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!goal.isArchived) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Arquivar meta?'),
          content: Text(
            '«${goal.name}» deixa de aparecer na lista. '
            'A conta e os movimentos não são alterados.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Arquivar'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) {
        return;
      }
    }
    try {
      await ref
          .read(savingsGoalRepositoryProvider)
          .setArchived(goal.id, archived: !goal.isArchived);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            goal.isArchived ? 'Meta reativada.' : 'Meta arquivada.',
          ),
        ),
      );
    } on AppFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.onEdit,
    required this.onToggleArchive,
  });

  final SavingsGoal goal;
  final VoidCallback onEdit;
  final VoidCallback onToggleArchive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = <String>[
      if (goal.targetDate != null) 'Até ${formatDate(goal.targetDate!)}',
      if (goal.linkedAccountName != null) goal.linkedAccountName!,
    ].join(' · ');
    return InkWell(
      onTap: onEdit,
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
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: goal.isReached
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHigh,
                    borderRadius: AppRadii.control,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Icon(
                      goal.isReached
                          ? Icons.check_circle_outline
                          : Icons.savings_outlined,
                      size: 20,
                      color: goal.isReached
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.name,
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (details.isNotEmpty)
                        Text(details, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                if (goal.isArchived)
                  const StatusBadge('Arquivada')
                else if (goal.isReached)
                  const StatusBadge('Concluída', tone: StatusTone.positive)
                else
                  StatusBadge(formatPercentage(goal.progress * 100)),
                PopupMenuButton<String>(
                  tooltip: 'Opções',
                  onSelected: (_) => onToggleArchive(),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'archive',
                      child: Text(
                        goal.isArchived ? 'Reativar meta' : 'Arquivar meta',
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            AppDataRow(
              label: 'Poupado',
              value: MoneyText(
                goal.currentAmount,
                style: theme.textTheme.bodyMedium,
                tone: MoneyTone.income,
                maxLines: 1,
              ),
            ),
            AppDataRow(
              label: 'Objetivo',
              value: MoneyText(
                goal.targetAmount,
                style: theme.textTheme.bodyMedium,
                maxLines: 1,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            ClipRRect(
              borderRadius: AppRadii.small,
              child: LinearProgressIndicator(
                value: goal.progress,
                minHeight: 8,
                color: goal.isReached
                    ? theme.colorScheme.tertiary
                    : theme.colorScheme.primary,
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
        : 'Não foi possível carregar as metas.';
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
