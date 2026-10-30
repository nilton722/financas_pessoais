import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/formatters/plural_formatter.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/money_text.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/status_badge.dart';
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
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            96,
          ),
          children: [
            _ConsolidatedHeader(balances: value),
            const SizedBox(height: AppSpacing.md),
            SectionCard(
              title: 'Suas contas',
              subtitle:
                  '${PluralFormatter.count(value.length, 'conta', 'contas')}'
                  ' · toque para editar',
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Column(
                children: [
                  for (var index = 0; index < value.length; index++) ...[
                    if (index > 0) const Divider(height: 1),
                    _AccountTile(
                      entry: value[index],
                      onEdit: () => context.push(
                        '/accounts/${value[index].account.id}/edit',
                      ),
                      onToggleArchive: () =>
                          _toggleArchive(context, ref, value[index].account),
                    ),
                  ],
                ],
              ),
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
    final negative = total < 0;
    final background = negative
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.primary;
    final foreground = negative
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onPrimary;
    return Card(
      color: background,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 18,
                  color: foreground,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Saldo consolidado',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: foreground,
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: foreground.withValues(alpha: 0.35),
                    ),
                    borderRadius: AppRadii.badge,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xxs,
                    ),
                    child: Text(
                      'FCFA',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            MoneyText(
              total,
              semanticsLabel:
                  'Saldo consolidado: '
                  '${MoneyFormatter.formatXof(total)}',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${PluralFormatter.count(active, 'conta ativa', 'contas ativas')}'
              ' · exclui arquivadas e outras moedas',
              style: theme.textTheme.bodySmall?.copyWith(
                color: foreground.withValues(alpha: 0.8),
              ),
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
    final balance = entry.balance;
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: account.isArchived
              ? theme.colorScheme.surfaceContainerHigh
              : theme.colorScheme.secondaryContainer,
          borderRadius: AppRadii.badge,
        ),
        child: Icon(
          _iconFor(account.type),
          size: 20,
          color: account.isArchived
              ? theme.colorScheme.onSurfaceVariant
              : theme.colorScheme.onSecondaryContainer,
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              account.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (account.isArchived) ...[
            const SizedBox(width: AppSpacing.sm),
            const StatusBadge('Arquivada'),
          ],
        ],
      ),
      subtitle: Text(account.type.label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: MoneyText(
              balance,
              tone: balance < 0 ? MoneyTone.expense : MoneyTone.neutral,
              style: theme.textTheme.titleSmall,
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Opções',
            icon: Icon(
              Icons.more_vert,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            padding: EdgeInsets.zero,
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
