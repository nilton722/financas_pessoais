import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/widgets/empty_state.dart';
import '../domain/account.dart';
import '../domain/account_balance.dart';
import 'accounts_providers.dart';

class AccountsPage extends ConsumerWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balances = ref.watch(accountBalancesProvider);
    final showArchived = ref.watch(showArchivedAccountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contas'),
        actions: [
          IconButton(
            tooltip: showArchived ? 'Ocultar arquivadas' : 'Mostrar arquivadas',
            icon: Icon(
              showArchived
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
            onPressed: () =>
                ref.read(showArchivedAccountsProvider.notifier).toggle(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/accounts/new'),
        icon: const Icon(Icons.add),
        label: const Text('Nova conta'),
      ),
      body: switch (balances) {
        AsyncData(:final value) when value.isEmpty => const EmptyState(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Sem contas',
          message: 'Cria a primeira conta para registar movimentos.',
        ),
        AsyncData(:final value) => ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            _ConsolidatedHeader(balances: value),
            for (final entry in value)
              _AccountTile(
                entry: entry,
                onEdit: () =>
                    context.push('/accounts/${entry.account.id}/edit'),
                onToggleArchive: () =>
                    _toggleArchive(context, ref, entry.account),
              ),
          ],
        ),
        AsyncError(:final error) => _ErrorView(
          error: error,
          onRetry: () => ref.invalidate(accountBalancesProvider),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Future<void> _toggleArchive(
    BuildContext context,
    WidgetRef ref,
    Account account,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!account.isArchived) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Arquivar conta?'),
          content: Text(
            'A conta «${account.name}» sai dos saldos consolidados. '
            'Os movimentos associados mantêm-se.',
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
      if (confirmed != true) {
        return;
      }
    }
    try {
      await ref
          .read(accountRepositoryProvider)
          .setArchived(account.id, archived: !account.isArchived);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            account.isArchived ? 'Conta reativada.' : 'Conta arquivada.',
          ),
        ),
      );
    } on AppFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }
}

class _ConsolidatedHeader extends StatelessWidget {
  const _ConsolidatedHeader({required this.balances});

  final List<AccountBalance> balances;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = consolidatedBalance(balances);
    final active = balances.where((entry) => !entry.account.isArchived).length;
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Saldo consolidado', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              MoneyFormatter.formatXof(total),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$active ${active == 1 ? 'conta ativa' : 'contas ativas'} · XOF',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.entry,
    required this.onEdit,
    required this.onToggleArchive,
  });

  final AccountBalance entry;
  final VoidCallback onEdit;
  final VoidCallback onToggleArchive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final account = entry.account;
    return ListTile(
      leading: CircleAvatar(child: Icon(_iconFor(account.type))),
      title: Text(
        account.isArchived ? '${account.name} (arquivada)' : account.name,
      ),
      subtitle: Text(account.type.label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            MoneyFormatter.formatXof(entry.balance),
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: entry.balance < 0 ? theme.colorScheme.error : null,
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Opções',
            onSelected: (_) => onToggleArchive(),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'archive',
                child: Text(
                  account.isArchived ? 'Reativar conta' : 'Arquivar conta',
                ),
              ),
            ],
          ),
        ],
      ),
      onTap: onEdit,
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

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error is AppFailure
        ? (error as AppFailure).message
        : 'Não foi possível carregar as contas.';
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
