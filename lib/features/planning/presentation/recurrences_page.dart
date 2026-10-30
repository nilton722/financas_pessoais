import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/formatters/date_formatter.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/widgets/empty_state.dart';
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
                : '$created ocorrência(s) criada(s).',
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
        AsyncData(:final value) when value.isEmpty => const EmptyState(
          icon: Icons.repeat_outlined,
          title: 'Sem recorrências',
          message:
              'Cria uma regra semanal, mensal ou anual para gerar '
              'compromissos futuros automaticamente.',
        ),
        AsyncData(:final value) => ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            for (final rule in value)
              _RuleTile(
                rule: rule,
                onEdit: () =>
                    context.push('/planning/recurrences/${rule.id}/edit'),
                onToggle: (active) => _toggle(context, ref, rule, active),
              ),
          ],
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
    final details = <String>[
      rule.frequency.label,
      'próxima ${formatDate(rule.nextOccurrenceDate)}',
      rule.kind.label,
      if (rule.categoryName != null) rule.categoryName!,
      if (rule.accountName != null) rule.accountName!,
    ].join(' · ');
    return ListTile(
      leading: CircleAvatar(
        child: Icon(
          rule.kind == PlannedItemKind.income
              ? Icons.trending_up
              : Icons.trending_down,
        ),
      ),
      title: Text(rule.description),
      subtitle: Text('$details\n${MoneyFormatter.formatXof(rule.amount)}'),
      isThreeLine: true,
      trailing: Switch(value: rule.isActive, onChanged: onToggle),
      onTap: onEdit,
      textColor: rule.isActive ? null : theme.disabledColor,
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
