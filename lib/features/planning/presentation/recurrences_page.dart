import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/formatters/date_formatter.dart';
import '../../../core/formatters/plural_formatter.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/money_text.dart';
import '../../../core/widgets/status_badge.dart';
import '../domain/planned_item.dart';
import '../domain/recurrence.dart';
import 'planning_format.dart';
import 'planning_providers.dart';

class RecurrencesPage extends ConsumerWidget {
  const RecurrencesPage({super.key});

  Future<void> _sync(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final created = await ref
          .read(planningRepositoryProvider)
          .syncRecurrences(
            horizon: FinancialDate.today().add(const Duration(days: 90)),
          );
      ref
        ..invalidate(recurringRulesProvider)
        ..invalidate(plannedItemsProvider)
        ..invalidate(pendingPlannedItemsProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            created == 0
                ? 'Sem novas ocorrências.'
                : '${PluralFormatter.count(created, 'ocorrência criada', 'ocorrências criadas')}.',
          ),
        ),
      );
    } on AppFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(recurringRulesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recorrências'),
        actions: [
          IconButton(
            tooltip: 'Gerar ocorrências até 90 dias',
            icon: const Icon(Icons.sync_outlined),
            onPressed: () => _sync(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/planning/recurrences/new'),
        icon: const Icon(Icons.add),
        label: const Text('Nova recorrência'),
      ),
      body: switch (rules) {
        AsyncData(:final value) when value.isEmpty => Center(
          child: SingleChildScrollView(
            padding: AppSpacing.page,
            child: EmptyState(
              icon: Icons.repeat_outlined,
              title: 'Sem recorrências',
              message:
                  'Cria uma regra semanal, mensal ou anual para gerar '
                  'compromissos futuros automaticamente.',
              action: FilledButton.icon(
                onPressed: () => context.push('/planning/recurrences/new'),
                icon: const Icon(Icons.add),
                label: const Text('Nova recorrência'),
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
            final rule = value[index];
            return Card(
              clipBehavior: Clip.antiAlias,
              child: _RuleTile(
                rule: rule,
                onEdit: () =>
                    context.push('/planning/recurrences/${rule.id}/edit'),
                onToggle: (active) => _toggle(context, ref, rule, active),
              ),
            );
          },
        ),
        AsyncError(:final error) => _ErrorView(
          error: error,
          onRetry: () => ref.invalidate(recurringRulesProvider),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    RecurringRule rule,
    bool active,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(planningRepositoryProvider)
          .setRuleActive(rule.id, active: active);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            active ? 'Recorrência reativada.' : 'Recorrência pausada.',
          ),
        ),
      );
    } on AppFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({
    required this.rule,
    required this.onEdit,
    required this.onToggle,
  });

  final RecurringRule rule;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final income = rule.kind == PlannedItemKind.income;
    final details = <String>[
      rule.frequency.label,
      'próxima ${formatDate(rule.nextOccurrenceDate)}',
      if (rule.categoryName != null) rule.categoryName!,
      if (rule.accountName != null) rule.accountName!,
    ].join(' · ');
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      leading: DecoratedBox(
        decoration: BoxDecoration(
          color: rule.isActive
              ? (income
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.errorContainer)
              : theme.colorScheme.surfaceContainerHigh,
          borderRadius: AppRadii.control,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Icon(
            income ? Icons.trending_up : Icons.trending_down,
            size: 20,
            color: !rule.isActive
                ? theme.colorScheme.onSurfaceVariant
                : income
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onErrorContainer,
          ),
        ),
      ),
      title: Text(
        rule.description,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: rule.isActive
            ? null
            : TextStyle(color: theme.colorScheme.onSurfaceVariant),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xxs),
          Text(details, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xxs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusBadge(
                rule.isActive ? 'Ativa' : 'Pausada',
                tone: rule.isActive ? StatusTone.positive : StatusTone.neutral,
              ),
              MoneyText(
                rule.amount,
                style: theme.textTheme.labelMedium,
                tone: income ? MoneyTone.income : MoneyTone.expense,
                textAlign: TextAlign.start,
                maxLines: 1,
              ),
            ],
          ),
        ],
      ),
      isThreeLine: true,
      trailing: Switch(value: rule.isActive, onChanged: onToggle),
      onTap: onEdit,
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
        : 'Não foi possível carregar as recorrências.';
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
