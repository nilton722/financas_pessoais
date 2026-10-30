import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/formatters/date_formatter.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/widgets/empty_state.dart';
import '../../accounts/domain/account_balance.dart';
import '../../accounts/presentation/accounts_providers.dart';
import '../../forecast/domain/forecast.dart';
import '../../forecast/presentation/forecast_providers.dart';
import '../../planning/domain/budget.dart';
import '../../planning/domain/planned_item.dart';
import '../../planning/domain/savings_goal.dart';
import '../../planning/presentation/planning_format.dart';
import '../../planning/presentation/planning_providers.dart';
import '../../settings/domain/app_settings.dart';
import '../../settings/presentation/settings_providers.dart';
import '../../transactions/domain/movement.dart';
import '../../transactions/presentation/transactions_providers.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balances = ref.watch(accountBalancesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finanças Pessoais'),
        actions: [
          IconButton(
            key: const Key('dashboard-reports'),
            tooltip: 'Relatórios',
            icon: const Icon(Icons.query_stats_outlined),
            onPressed: () => context.push('/reports'),
          ),
          IconButton(
            key: const Key('dashboard-settings'),
            tooltip: 'Definições e privacidade',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: switch (balances) {
        AsyncData(:final value) => _DashboardContent(balances: value),
        AsyncError(:final error) => _FailureContent(
          error: error,
          onRetry: () {
            ref.invalidate(accountBalancesProvider);
            ref.invalidate(movementListProvider);
            ref.invalidate(appSettingsProvider);
          },
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _DashboardContent extends ConsumerWidget {
  const _DashboardContent({required this.balances});

  final List<AccountBalance> balances;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final month = ref.watch(
      movementListProvider(MovementFilter.forMonth(DateTime.now())),
    );
    final settings = ref.watch(appSettingsProvider);
    final forecast = ref.watch(forecastBundleProvider);
    final budgets = ref.watch(budgetsProvider).value ?? const <Budget>[];
    final pending =
        ref.watch(pendingPlannedItemsProvider).value ?? const <PlannedItem>[];
    final goals =
        ref.watch(savingsGoalsProvider).value ?? const <SavingsGoal>[];
    final budgetMonth = ref.watch(budgetMonthProvider);
    final activeBalances = balances
        .where((entry) => !entry.account.isArchived)
        .toList(growable: false);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(accountBalancesProvider);
        ref.invalidate(movementListProvider);
        ref.invalidate(appSettingsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _BalanceCard(balances: balances),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: 'Rendimentos do mês',
                  amount: month.value?.totals.income,
                  icon: Icons.trending_up,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  label: 'Despesas do mês',
                  amount: month.value?.totals.expense,
                  icon: Icons.trending_down,
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ForecastSummaryCard(
            forecast: forecast,
            onOpen: () => context.push('/forecast'),
          ),
          const SizedBox(height: 12),
          _PlanningSummaryCard(
            month: budgetMonth,
            budgets: budgets,
            pending: pending,
            goals: goals,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Contas',
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        if (activeBalances.length > 5)
                          TextButton(
                            onPressed: () => context.go('/accounts'),
                            child: const Text('Ver todas'),
                          ),
                      ],
                    ),
                  ),
                  if (activeBalances.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: EmptyState(
                        icon: Icons.account_balance_outlined,
                        title: 'Ainda sem contas',
                        message:
                            'Crie a primeira conta para registar movimentos.',
                      ),
                    )
                  else
                    for (final entry in activeBalances.take(5))
                      ListTile(
                        title: Text(entry.account.name),
                        subtitle: Text(entry.account.type.label),
                        trailing: Text(
                          MoneyFormatter.formatXof(entry.balance),
                          style: theme.textTheme.bodyLarge,
                        ),
                        onTap: () =>
                            context.push('/accounts/${entry.account.id}/edit'),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => context.push('/movements/new'),
                  icon: const Icon(Icons.add),
                  label: const Text('Novo movimento'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/movements'),
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Movimentos'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.lock_outline),
            label: const Text('Privacidade e backup'),
          ),
          const SizedBox(height: 8),
          Text(
            'Dados apenas neste dispositivo · '
            '${settings.value?.timeZone ?? AppSettings.defaults.timeZone}'
            ' · esquema v4',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balances});

  final List<AccountBalance> balances;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = consolidatedBalance(balances);
    final formatted = MoneyFormatter.formatXof(total);
    return Card(
      key: const Key('dashboard-balance-real'),
      color: theme.colorScheme.primaryContainer,
      child: Semantics(
        container: true,
        label:
            'Saldo real consolidado: $formatted. '
            'Apenas movimentos registados até hoje; exclui contas '
            'arquivadas e outras moedas.',
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 18,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Saldo real consolidado',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  formatted,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Movimentos registados até hoje · exclui arquivadas e '
                  'outras moedas',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  final String label;
  final int? amount;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(label, style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              amount == null ? '…' : MoneyFormatter.formatXof(amount!),
              style: theme.textTheme.titleMedium?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _ForecastSummaryCard extends StatelessWidget {
  const _ForecastSummaryCard({required this.forecast, required this.onOpen});

  final AsyncValue<ForecastBundle> forecast;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bundle = forecast.value;
    final result = bundle?.resultFor(30);
    final negative = result?.hasNegativeBalance ?? false;
    final subtitle = result == null
        ? (forecast.hasError
              ? 'Não foi possível calcular a previsão.'
              : 'A calcular…')
        : 'Saldo projetado ${MoneyFormatter.formatXof(result.closingBalance)} '
              'em 30 dias · mínimo ${MoneyFormatter.formatXof(result.lowestBalance)} '
              'em ${_formatDate(result.lowestDate)}';
    final background = negative
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.secondaryContainer;
    final foreground = negative
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onSecondaryContainer;
    return Card(
      key: const Key('dashboard-forecast'),
      color: background,
      child: Semantics(
        container: true,
        label:
            'Estimativa. Previsão a 30 dias. $subtitle. '
            'Valores projetados, não garantias; não alteram o saldo real.',
        child: ExcludeSemantics(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.surface,
              child: Icon(
                negative
                    ? Icons.warning_amber_outlined
                    : Icons.insights_outlined,
                color: negative ? theme.colorScheme.error : foreground,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    'Previsão (30 dias)',
                    style: TextStyle(color: foreground),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: foreground.withValues(alpha: 0.4),
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Projetado',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: foreground,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Text(subtitle, style: TextStyle(color: foreground)),
            trailing: Icon(Icons.chevron_right, color: foreground),
            onTap: onOpen,
          ),
        ),
      ),
    );
  }
}

class _PlanningSummaryCard extends StatelessWidget {
  const _PlanningSummaryCard({
    required this.month,
    required this.budgets,
    required this.pending,
    required this.goals,
  });

  final DateTime month;
  final List<Budget> budgets;
  final List<PlannedItem> pending;
  final List<SavingsGoal> goals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final limit = budgets.fold(
      0,
      (total, budget) => total + budget.limitAmount,
    );
    final spent = budgets.fold(0, (total, budget) => total + budget.spent);
    final exceeded = budgets.where((budget) => budget.isExceeded).length;
    final progress = limit <= 0 ? 0.0 : (spent / limit).clamp(0.0, 1.0);
    final payable = pending.where(
      (item) => item.kind == PlannedItemKind.expense,
    );
    final receivable = pending.where(
      (item) => item.kind == PlannedItemKind.income,
    );
    final payableTotal = payable.fold(
      0,
      (total, item) => total + item.remaining,
    );
    final receivableTotal = receivable.fold(
      0,
      (total, item) => total + item.remaining,
    );
    final nextDue = pending.isEmpty
        ? null
        : pending
              .map((item) => item.dueDate)
              .reduce((a, b) => a.isBefore(b) ? a : b);
    final activeGoals = goals.where((goal) => !goal.isArchived);
    final saved = activeGoals.fold(
      0,
      (total, goal) => total + goal.currentAmount,
    );
    final target = activeGoals.fold(
      0,
      (total, goal) => total + goal.targetAmount,
    );
    final reached = activeGoals.where((goal) => goal.isReached).length;

    return Card(
      key: const Key('dashboard-planning'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Planeamento',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/planning'),
                    child: const Text('Abrir'),
                  ),
                ],
              ),
            ),
            ListTile(
              key: const Key('dashboard-budget'),
              leading: const Icon(Icons.pie_chart_outline),
              title: const Text('Orçamentos'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    budgets.isEmpty
                        ? 'Sem orçamentos em ${formatMonth(month)}'
                        : 'Gasto ${MoneyFormatter.formatXof(spent)} de '
                              '${MoneyFormatter.formatXof(limit)}'
                              '${exceeded > 0 ? ' · $exceeded excedido(s)' : ''}',
                  ),
                  if (budgets.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        color: exceeded > 0
                            ? theme.colorScheme.error
                            : theme.colorScheme.primary,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ],
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/planning/budgets'),
            ),
            const Divider(height: 1),
            ListTile(
              key: const Key('dashboard-commitments'),
              leading: const Icon(Icons.event_note_outlined),
              title: const Text('Compromissos pendentes'),
              subtitle: Text(
                pending.isEmpty
                    ? 'Sem compromissos pendentes'
                    : '${payable.length} a pagar · '
                          '${MoneyFormatter.formatXof(payableTotal)}'
                          '${receivable.isEmpty ? '' : ' · ${receivable.length} a receber · '
                                    '${MoneyFormatter.formatXof(receivableTotal)}'}'
                          '${nextDue == null ? '' : '\nPróximo vencimento: '
                                    '${_formatDate(nextDue)}'}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/planning/commitments'),
            ),
            const Divider(height: 1),
            ListTile(
              key: const Key('dashboard-goals'),
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Metas de poupança'),
              subtitle: Text(
                activeGoals.isEmpty
                    ? 'Sem metas ativas'
                    : '${activeGoals.length} meta(s) · '
                          '${MoneyFormatter.formatXof(saved)} de '
                          '${MoneyFormatter.formatXof(target)}'
                          '${reached > 0 ? ' · $reached alcançada(s)' : ''}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/planning/goals'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FailureContent extends StatelessWidget {
  const _FailureContent({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error is AppFailure
        ? (error as AppFailure).message
        : 'Não foi possível abrir a base de dados local.';
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

String _formatDate(DateTime date) =>
    FinancialDate.toDisplay(FinancialDate.fromDateTime(date));
