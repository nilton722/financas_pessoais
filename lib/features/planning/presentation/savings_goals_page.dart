import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/widgets/empty_state.dart';
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
        AsyncData(:final value) when value.isEmpty => const EmptyState(
          icon: Icons.savings_outlined,
          title: 'Sem metas',
          message:
              'Define um alvo e associa uma conta de poupança para '
              'acompanhar o progresso a partir do saldo real.',
        ),
        AsyncData(:final value) => ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          children: [
            for (final goal in value)
              _GoalCard(
                goal: goal,
                onEdit: () => context.push('/planning/goals/${goal.id}/edit'),
                onToggleArchive: () => _toggleArchive(context, ref, goal),
              ),
          ],
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
      if (goal.isArchived) 'Arquivada',
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                child: Icon(
                  goal.isReached
                      ? Icons.check_circle_outline
                      : Icons.savings_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(goal.name, style: theme.textTheme.titleMedium),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(details, style: theme.textTheme.bodySmall),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      '${MoneyFormatter.formatXof(goal.currentAmount)} de '
                      '${MoneyFormatter.formatXof(goal.targetAmount)} · '
                      '${formatPercentage(goal.progress * 100)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
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
