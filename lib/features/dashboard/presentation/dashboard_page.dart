import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/widgets/empty_state.dart';
import '../../accounts/domain/account_balance.dart';
import '../../accounts/presentation/accounts_providers.dart';
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
      appBar: AppBar(title: const Text('Finanças Pessoais')),
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
          const SizedBox(height: 20),
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
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saldo consolidado',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              MoneyFormatter.formatXof(total),
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Exclui contas arquivadas e outras moedas',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ],
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
