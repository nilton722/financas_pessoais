import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/money_text.dart';
import '../../../core/widgets/status_badge.dart';
import '../domain/planned_item.dart';
import 'planning_format.dart';
import 'planning_providers.dart';

class CommitmentsPage extends ConsumerStatefulWidget {
  const CommitmentsPage({super.key});

  @override
  ConsumerState<CommitmentsPage> createState() => _CommitmentsPageState();
}

class _CommitmentsPageState extends ConsumerState<CommitmentsPage> {
  bool _showSettled = false;

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(
      _showSettled ? plannedItemsProvider : pendingPlannedItemsProvider,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compromissos'),
        actions: [
          IconButton(
            tooltip: _showSettled
                ? 'Mostrar apenas pendentes'
                : 'Mostrar liquidados',
            icon: Icon(
              _showSettled
                  ? Icons.filter_alt_off_outlined
                  : Icons.filter_alt_outlined,
            ),
            onPressed: () => setState(() => _showSettled = !_showSettled),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/planning/commitments/new'),
        icon: const Icon(Icons.add),
        label: const Text('Novo compromisso'),
      ),
      body: switch (items) {
        AsyncData(:final value) when value.isEmpty => Center(
          child: SingleChildScrollView(
            padding: AppSpacing.page,
            child: EmptyState(
              icon: Icons.event_note_outlined,
              title: _showSettled
                  ? 'Sem compromissos'
                  : 'Sem compromissos pendentes',
              message: _showSettled
                  ? 'Cria um compromisso para prever rendimentos ou despesas.'
                  : 'Tudo em dia. Os compromissos aparecem aqui até serem pagos.',
              action: FilledButton.icon(
                onPressed: () => context.push('/planning/commitments/new'),
                icon: const Icon(Icons.add),
                label: const Text('Novo compromisso'),
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
            final item = value[index];
            return Card(
              clipBehavior: Clip.antiAlias,
              child: _CommitmentTile(
                item: item,
                onEdit: () =>
                    context.push('/planning/commitments/${item.id}/edit'),
                onPay: () =>
                    context.push('/planning/commitments/${item.id}/pay'),
                onCancel: () => _cancel(item),
              ),
            );
          },
        ),
        AsyncError(:final error) => _ErrorView(
          error: error,
          onRetry: () => ref
            ..invalidate(plannedItemsProvider)
            ..invalidate(pendingPlannedItemsProvider),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Future<void> _cancel(PlannedItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancelar compromisso?'),
        content: Text(
          '«${item.description}» sai da previsão. Pagamentos já feitos '
          'mantêm os movimentos reais.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancelar compromisso'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(planningRepositoryProvider).cancelItem(item.id);
      messenger.showSnackBar(
        const SnackBar(content: Text('Compromisso cancelado.')),
      );
    } on AppFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }
}

class _CommitmentTile extends StatelessWidget {
  const _CommitmentTile({
    required this.item,
    required this.onEdit,
    required this.onPay,
    required this.onCancel,
  });

  final PlannedItem item;
  final VoidCallback onEdit;
  final VoidCallback onPay;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final income = item.kind == PlannedItemKind.income;
    final details = <String>[
      formatDate(item.dueDate),
      item.kind.label,
      if (item.categoryName != null) item.categoryName!,
      if (item.accountName != null) item.accountName!,
    ].join(' · ');
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      leading: DecoratedBox(
        decoration: BoxDecoration(
          color: income
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.errorContainer,
          borderRadius: AppRadii.control,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Icon(
            income ? Icons.trending_up : Icons.trending_down,
            size: 20,
            color: income
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onErrorContainer,
          ),
        ),
      ),
      title: Text(
        item.description,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
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
                item.effectiveStatus.label,
                tone: _statusTone(item.effectiveStatus),
              ),
              if (item.paidTotal > 0 && item.isOpen)
                Text(
                  'pago ${MoneyFormatter.formatXof(item.paidTotal)}',
                  style: theme.textTheme.labelSmall,
                ),
            ],
          ),
        ],
      ),
      isThreeLine: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 116),
            child: MoneyText(
              item.remaining,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              tone: item.isOpen
                  ? (income ? MoneyTone.income : MoneyTone.expense)
                  : MoneyTone.neutral,
              maxLines: 1,
            ),
          ),
          if (item.isOpen)
            PopupMenuButton<String>(
              tooltip: 'Opções',
              onSelected: (value) {
                if (value == 'pay') {
                  onPay();
                } else {
                  onCancel();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'pay', child: Text('Pagar')),
                PopupMenuItem(
                  value: 'cancel',
                  child: Text('Cancelar compromisso'),
                ),
              ],
            ),
        ],
      ),
      onTap: item.isOpen ? onEdit : null,
    );
  }
}

StatusTone _statusTone(PlannedItemStatus status) => switch (status) {
  PlannedItemStatus.planned => StatusTone.neutral,
  PlannedItemStatus.partiallyPaid => StatusTone.warning,
  PlannedItemStatus.paid => StatusTone.positive,
  PlannedItemStatus.cancelled => StatusTone.danger,
};

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error is AppFailure
        ? (error as AppFailure).message
        : 'Não foi possível carregar os compromissos.';
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
