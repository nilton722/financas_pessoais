import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/formatters/date_formatter.dart';
import '../../../core/formatters/money_formatter.dart';
import '../domain/budget.dart';
import '../domain/debt.dart';
import '../domain/planned_item.dart';
import 'planning_format.dart';
import 'planning_providers.dart';

class PlanningHubPage extends ConsumerStatefulWidget {
  const PlanningHubPage({super.key});

  @override
  ConsumerState<PlanningHubPage> createState() => _PlanningHubPageState();
}

class _PlanningHubPageState extends ConsumerState<PlanningHubPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_syncRecurrences);
  }

  /// Materializa as próximas ocorrências ao abrir o planeamento. É
  /// idempotente e não bloqueia a interface.
  Future<void> _syncRecurrences() async {
    try {
      await ref
          .read(planningRepositoryProvider)
          .syncRecurrences(
            horizon: FinancialDate.today().add(const Duration(days: 90)),
          );
    } on AppFailure catch (failure) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  Future<void> _refresh() async {
    await _syncRecurrences();
    ref
      ..invalidate(plannedItemsProvider)
      ..invalidate(pendingPlannedItemsProvider)
      ..invalidate(recurringRulesProvider)
      ..invalidate(savingsGoalsProvider)
      ..invalidate(debtsProvider)
      ..invalidate(budgetsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alerts = ref.watch(planningAlertsProvider);
    final pending =
        ref.watch(pendingPlannedItemsProvider).value ?? const <PlannedItem>[];
    final budgets = ref.watch(budgetsProvider).value ?? const <Budget>[];
    final rules = ref.watch(recurringRulesProvider).value ?? const [];
    final goals = ref.watch(savingsGoalsProvider).value ?? const [];
    final debts = ref.watch(debtsProvider).value ?? const <Debt>[];
    final month = ref.watch(budgetMonthProvider);

    final pendingTotal = pending.fold(
      0,
      (total, item) => total + item.remaining,
    );
    final openDebts = debts.where((debt) => debt.isOpen).toList();
    final payable = openDebts
        .where((debt) => debt.kind == DebtKind.payable)
        .fold(0, (total, debt) => total + debt.remaining);
    final receivable = openDebts
        .where((debt) => debt.kind == DebtKind.receivable)
        .fold(0, (total, debt) => total + debt.remaining);
    final budgetLimit = budgets.fold(
      0,
      (total, budget) => total + budget.limitAmount,
    );
    final budgetSpent = budgets.fold(
      0,
      (total, budget) => total + budget.spent,
    );
    final exceeded = budgets.where((budget) => budget.isExceeded).length;
    final activeRules = rules.where((rule) => rule.isActive).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planeamento'),
        actions: [
          IconButton(
            tooltip: 'Atualizar recorrências',
            icon: const Icon(Icons.sync_outlined),
            onPressed: _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (alerts.isNotEmpty) ...[
              Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Text(
                          'Alertas',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                      for (final alert in alerts)
                        ListTile(
                          leading: Icon(
                            alert.icon,
                            color: theme.colorScheme.onErrorContainer,
                          ),
                          title: Text(
                            alert.title,
                            style: TextStyle(
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                          subtitle: Text(
                            alert.message,
                            style: TextStyle(
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                          onTap: () => context.go(alert.route),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Card(
              child: Column(
                children: [
                  _PlanningTile(
                    icon: Icons.event_note_outlined,
                    title: 'Compromissos',
                    subtitle: pending.isEmpty
                        ? 'Sem compromissos pendentes'
                        : '${pending.length} pendentes · '
                              '${MoneyFormatter.formatXof(pendingTotal)}',
                    route: '/planning/commitments',
                  ),
                  const Divider(height: 1),
                  _PlanningTile(
                    icon: Icons.pie_chart_outline,
                    title: 'Orçamentos',
                    subtitle: budgets.isEmpty
                        ? 'Sem orçamentos em ${formatMonth(month)}'
                        : '${formatMonth(month)} · Gasto '
                              '${MoneyFormatter.formatXof(budgetSpent)} de '
                              '${MoneyFormatter.formatXof(budgetLimit)}'
                              '${exceeded > 0 ? ' · $exceeded excedido(s)' : ''}',
                    route: '/planning/budgets',
                  ),
                  const Divider(height: 1),
                  _PlanningTile(
                    icon: Icons.repeat_outlined,
                    title: 'Recorrências',
                    subtitle: rules.isEmpty
                        ? 'Sem regras recorrentes'
                        : '$activeRules ativas de ${rules.length}',
                    route: '/planning/recurrences',
                  ),
                  const Divider(height: 1),
                  _PlanningTile(
                    icon: Icons.savings_outlined,
                    title: 'Metas de poupança',
                    subtitle: goals.isEmpty
                        ? 'Sem metas definidas'
                        : '${goals.length} '
                              '${goals.length == 1 ? 'meta' : 'metas'}',
                    route: '/planning/goals',
                  ),
                  const Divider(height: 1),
                  _PlanningTile(
                    icon: Icons.handshake_outlined,
                    title: 'Dívidas',
                    subtitle: openDebts.isEmpty
                        ? 'Sem dívidas em aberto'
                        : 'A pagar ${MoneyFormatter.formatXof(payable)} · '
                              'A receber ${MoneyFormatter.formatXof(receivable)}',
                    route: '/planning/debts',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Compromissos e ocorrências são previsões: só os movimentos '
              'reais alteram o saldo.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanningTile extends StatelessWidget {
  const _PlanningTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(child: Icon(icon)),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(route),
    );
  }
}
