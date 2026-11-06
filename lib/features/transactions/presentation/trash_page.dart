import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/finance_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/formatters/date_formatter.dart';
import '../../../core/formatters/plural_formatter.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/money_text.dart';
import '../domain/movement.dart';
import 'transactions_providers.dart';

/// Movimentos eliminados. Restaurar devolve o movimento aos saldos, listas e
/// relatórios; eliminar definitivamente apaga-o da base e não pode ser
/// desfeito.
class TrashPage extends ConsumerWidget {
  const TrashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movements = ref.watch(deletedMovementsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Lixeira')),
      body: switch (movements) {
        AsyncData(:final value) when value.isEmpty => const Center(
          child: SingleChildScrollView(
            padding: AppSpacing.page,
            child: EmptyState(
              icon: Icons.delete_outline,
              title: 'Lixeira vazia',
              message:
                  'Os movimentos eliminados aparecem aqui e podem ser '
                  'restaurados ou apagados definitivamente.',
            ),
          ),
        ),
        AsyncData(:final value) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            Text(
              'Estes movimentos não contam para saldos, relatórios nem '
              'previsões. Restaurar devolve-os tal como estavam; se estavam '
              'ligados a um compromisso ou dívida, a ligação é reposta.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              PluralFormatter.count(
                value.length,
                'movimento eliminado',
                'movimentos eliminados',
              ),
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final item in value) ...[
              _TrashTile(
                item: item,
                onRestore: () => _restore(context, ref, item.movement),
                onDelete: () => _deleteForever(context, ref, item.movement),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
        AsyncError(:final error) => Center(
          child: Padding(
            padding: AppSpacing.page,
            child: Text(
              error is AppFailure
                  ? error.message
                  : 'Não foi possível carregar a lixeira.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Future<void> _restore(
    BuildContext context,
    WidgetRef ref,
    Movement movement,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(transactionRepositoryProvider).restore(movement.id);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Movimento restaurado. Saldos atualizados.'),
        ),
      );
    } on AppFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  Future<void> _deleteForever(
    BuildContext context,
    WidgetRef ref,
    Movement movement,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar definitivamente?'),
        content: const Text(
          'O movimento é apagado da base de dados. Esta operação não pode ser '
          'desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await ref
          .read(transactionRepositoryProvider)
          .deletePermanently(movement.id);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(content: Text('Movimento eliminado definitivamente.')),
      );
    } on AppFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }
}

class _TrashTile extends StatelessWidget {
  const _TrashTile({
    required this.item,
    required this.onRestore,
    required this.onDelete,
  });

  final MovementListItem item;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final finance = FinanceColors.of(context);
    final movement = item.movement;
    final tone = movement.kind == MovementKind.income
        ? MoneyTone.income
        : (movement.kind == MovementKind.expense
              ? MoneyTone.expense
              : MoneyTone.transfer);
    final (background, foreground, icon) = switch (movement.kind) {
      MovementKind.income => (
        finance.incomeContainer,
        finance.onIncomeContainer,
        Icons.south_west,
      ),
      MovementKind.expense => (
        theme.colorScheme.errorContainer,
        theme.colorScheme.onErrorContainer,
        Icons.north_east,
      ),
      MovementKind.transfer => (
        finance.transferContainer,
        finance.onTransferContainer,
        Icons.swap_horiz,
      ),
    };
    final title =
        movement.description ??
        item.categoryName ??
        (movement.kind.isTransfer ? 'Transferência' : 'Sem descrição');
    final details = [
      if (item.categoryName != null) item.categoryName!,
      item.accountName,
      FinancialDate.toDisplay(FinancialDate.fromDateTime(movement.date)),
    ].join(' · ');

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: background,
                borderRadius: AppRadii.badge,
              ),
              child: Icon(icon, size: 20, color: foreground),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    details,
                    style: theme.textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  MoneyText(
                    movement.kind == MovementKind.expense
                        ? -movement.amount
                        : movement.amount,
                    signed: !movement.kind.isTransfer,
                    tone: tone,
                    style: theme.textTheme.labelLarge,
                  ),
                ],
              ),
            ),
            IconButton(
              key: Key('trash-restore-${movement.id}'),
              tooltip: 'Restaurar',
              icon: const Icon(Icons.restore_from_trash_outlined),
              onPressed: onRestore,
            ),
            IconButton(
              key: Key('trash-delete-${movement.id}'),
              tooltip: 'Eliminar definitivamente',
              icon: const Icon(Icons.delete_forever_outlined),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
