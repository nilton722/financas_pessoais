import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/widgets/empty_state.dart';
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
        AsyncData(:final value) when value.isEmpty => EmptyState(
          icon: Icons.event_note_outlined,
          title: _showSettled
              ? 'Sem compromissos'
              : 'Sem compromissos pendentes',
          message: _showSettled
              ? 'Cria um compromisso para prever rendimentos ou despesas.'
              : 'Tudo em dia. Os compromissos aparecem aqui até serem pagos.',
        ),
        AsyncData(:final value) => ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            for (final item in value)
              _CommitmentTile(
                item: item,
                onEdit: () =>
                    context.push('/planning/commitments/${item.id}/edit'),
                onPay: () =>
                    context.push('/planning/commitments/${item.id}/pay'),
                onCancel: () => _cancel(item),
              ),
          ],
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
    final details = <String>[
      formatDate(item.dueDate),
      item.kind.label,
      if (item.categoryName != null) item.categoryName!,
      if (item.accountName != null) item.accountName!,
    ].join(' · ');
    return ListTile(
      leading: CircleAvatar(
        child: Icon(
          item.kind == PlannedItemKind.income
              ? Icons.trending_up
              : Icons.trending_down,
        ),
      ),
      title: Text(item.description),
      subtitle: Text(
        '$details\n${item.effectiveStatus.label}'
        '${item.paidTotal > 0 && item.isOpen ? ' · pago '
                  '${MoneyFormatter.formatXof(item.paidTotal)}' : ''}',
      ),
      isThreeLine: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            MoneyFormatter.formatXof(item.remaining),
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
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
