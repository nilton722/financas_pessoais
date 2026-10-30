import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/finance_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/formatters/date_formatter.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/formatters/plural_formatter.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/money_text.dart';
import '../../../core/widgets/section_card.dart';
import '../../accounts/domain/account.dart';
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
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          _BalanceCard(balances: balances),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: 'Rendimentos do mês',
                  amount: month.value?.totals.income,
                  icon: Icons.south_west,
                  tone: MoneyTone.income,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _MetricCard(
                  label: 'Despesas do mês',
                  amount: month.value?.totals.expense,
                  icon: Icons.north_east,
                  tone: MoneyTone.expense,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _ForecastSummaryCard(
            forecast: forecast,
            onOpen: () => context.push('/forecast'),
          ),
          const SizedBox(height: AppSpacing.md),
          _PlanningSummaryCard(
            month: budgetMonth,
            budgets: budgets,
            pending: pending,
            goals: goals,
          ),
          const SizedBox(height: AppSpacing.md),
          SectionCard(
            title: 'Contas',
            subtitle: activeBalances.isEmpty
                ? 'Nenhuma conta ativa'
                : PluralFormatter.count(
                    activeBalances.length,
                    'conta ativa',
                    'contas ativas',
                  ),
            action: activeBalances.length > 5
                ? TextButton(
                    onPressed: () => context.go('/accounts'),
                    child: const Text('Ver todas'),
                  )
                : null,
            padding: const EdgeInsets.only(
              top: AppSpacing.xs,
              bottom: AppSpacing.xs,
            ),
            child: activeBalances.isEmpty
                ? const EmptyState(
                    icon: Icons.account_balance_outlined,
                    title: 'Ainda sem contas',
                    message: 'Crie a primeira conta para registar movimentos.',
                  )
                : Column(
                    children: [
                      for (final entry in activeBalances.take(5))
                        _AccountRow(entry: entry),
                    ],
                  ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => context.push('/movements/new'),
                  icon: const Icon(Icons.add),
                  label: const Text('Novo movimento'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/movements'),
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Movimentos'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: TextButton.icon(
              onPressed: () => context.push('/settings'),
              icon: const Icon(Icons.lock_outline, size: 18),
              label: const Text('Privacidade e backup'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.smartphone_outlined,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  'Dados apenas neste dispositivo · '
                  '${settings.value?.timeZone ?? AppSettings.defaults.timeZone}'
                  ' · esquema v4',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
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
    final negative = total < 0;
    final background = negative
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.primary;
    final foreground = negative
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onPrimary;
    final formatted = MoneyFormatter.formatXof(total);
    final active = balances.where((entry) => !entry.account.isArchived).length;
    return Card(
      key: const Key('dashboard-balance-real'),
      color: background,
      child: Semantics(
        container: true,
        label:
            'Saldo real consolidado: $formatted. '
            'Apenas movimentos registados até hoje; exclui contas '
            'arquivadas e outras moedas.',
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: foreground.withValues(alpha: 0.14),
                        borderRadius: AppRadii.small,
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 18,
                        color: foreground,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Saldo real consolidado',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: foreground,
                        ),
                      ),
                    ),
                    _SoftBadge(
                      label: negative ? 'Negativo' : 'Hoje',
                      foreground: foreground,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                MoneyText(
                  total,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${PluralFormatter.count(active, 'conta ativa', 'contas ativas')}'
                  ' · movimentos registados até hoje',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: foreground.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Exclui contas arquivadas e outras moedas',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: foreground.withValues(alpha: 0.7),
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

class _SoftBadge extends StatelessWidget {
  const _SoftBadge({required this.label, required this.foreground});

  final String label;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: foreground.withValues(alpha: 0.35)),
        borderRadius: AppRadii.badge,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: foreground, fontWeight: FontWeight.w700),
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
    required this.tone,
  });

  final String label;
  final int? amount;
  final IconData icon;
  final MoneyTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final finance = FinanceColors.of(context);
    final toneColor = switch (tone) {
      MoneyTone.income => finance.income,
      MoneyTone.expense => theme.colorScheme.error,
      _ => theme.colorScheme.primary,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                color: toneColor.withValues(alpha: 0.12),
                borderRadius: AppRadii.small,
              ),
              child: Icon(icon, size: 18, color: toneColor),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(label, style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.xxs),
            if (amount == null)
              Text('…', style: theme.textTheme.titleLarge)
            else
              MoneyText(
                amount!,
                compact: true,
                tone: tone,
                semanticsLabel: '$label: ${MoneyFormatter.formatXof(amount!)}',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
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
        : 'Saldo projetado ${MoneyFormatter.formatXofCompact(result.closingBalance)} '
              'em 30 dias · mínimo '
              '${MoneyFormatter.formatXofCompact(result.lowestBalance)} '
              'em ${_formatDate(result.lowestDate)}';
    final exactSubtitle = result == null
        ? null
        : 'Saldo projetado ${MoneyFormatter.formatXof(result.closingBalance)} '
              'em 30 dias · mínimo '
              '${MoneyFormatter.formatXof(result.lowestBalance)} '
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
            'Estimativa. Previsão a 30 dias. ${exactSubtitle ?? subtitle}. '
            'Valores projetados, não garantias; não alteram o saldo real.',
        child: ExcludeSemantics(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.surface,
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
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: foreground,
                    ),
                  ),
                ),
                _SoftBadge(label: 'Projetado', foreground: foreground),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(color: foreground),
              ),
            ),
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
    final finance = FinanceColors.of(context);
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

    return SectionCard(
      key: const Key('dashboard-planning'),
      title: 'Planeamento',
      action: TextButton(
        onPressed: () => context.go('/planning'),
        child: const Text('Abrir'),
      ),
      padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: AppSpacing.xs),
      child: Column(
        children: [
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
                            '${exceeded > 0 ? ' · ${PluralFormatter.count(exceeded, 'excedido', 'excedidos')}' : ''}',
                ),
                if (budgets.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  ClipRRect(
                    borderRadius: AppRadii.small,
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      color: exceeded > 0
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                      backgroundColor: theme.colorScheme.surfaceContainerHigh,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
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
                  : '${PluralFormatter.count(activeGoals.length, 'meta', 'metas')} · '
                        '${MoneyFormatter.formatXof(saved)} de '
                        '${MoneyFormatter.formatXof(target)}'
                        '${reached > 0 ? ' · ${PluralFormatter.count(reached, 'alcançada', 'alcançadas')}' : ''}',
            ),
            trailing: Icon(
              activeGoals.isEmpty ? Icons.chevron_right : Icons.flag_outlined,
              color: activeGoals.isEmpty ? null : finance.positive,
            ),
            onTap: () => context.push('/planning/goals'),
          ),
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.entry});

  final AccountBalance entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final balance = entry.balance;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.surfaceContainerHigh,
        child: Icon(_iconFor(entry.account.type), size: 20),
      ),
      title: Text(entry.account.name),
      subtitle: Text(entry.account.type.label),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 150),
        child: MoneyText(
          balance,
          tone: balance < 0 ? MoneyTone.expense : MoneyTone.neutral,
          style: theme.textTheme.titleSmall,
        ),
      ),
      onTap: () => context.push('/accounts/${entry.account.id}/edit'),
    );
  }

  IconData _iconFor(AccountType type) => switch (type) {
    AccountType.cash => Icons.payments_outlined,
    AccountType.bank => Icons.account_balance_outlined,
    AccountType.mobileWallet => Icons.smartphone_outlined,
    AccountType.savings => Icons.savings_outlined,
    AccountType.other => Icons.wallet_outlined,
  };
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
        padding: const EdgeInsets.all(AppSpacing.xl),
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

String _formatDate(DateTime date) =>
    FinancialDate.toDisplay(FinancialDate.fromDateTime(date));
