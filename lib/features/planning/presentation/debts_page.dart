import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/widgets/empty_state.dart';
import '../domain/debt.dart';
import 'planning_format.dart';
import 'planning_providers.dart';

class DebtsPage extends ConsumerStatefulWidget {
  const DebtsPage({super.key});

  @override
  ConsumerState<DebtsPage> createState() => _DebtsPageState();
}

class _DebtsPageState extends ConsumerState<DebtsPage> {
  bool _showSettled = false;

  @override
  Widget build(BuildContext context) {
    final debts = ref.watch(debtsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dívidas'),
        actions: [
          IconButton(
            tooltip: _showSettled
                ? 'Mostrar apenas em aberto'
                : 'Mostrar liquidadas',
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
        onPressed: () => context.push('/planning/debts/new'),
        icon: const Icon(Icons.add),
        label: const Text('Nova dívida'),
      ),
      body: switch (debts) {
        AsyncData(:final value) when value.isEmpty => const EmptyState(
          icon: Icons.handshake_outlined,
          title: 'Sem dívidas',
          message:
              'Regista valores a pagar ou a receber. O pendente é '
              'calculado a partir dos pagamentos reais.',
        ),
        AsyncData(:final value) => _DebtsList(
          debts: _showSettled
              ? value
              : value.where((debt) => debt.isOpen).toList(),
          onEdit: (debt) => context.push('/planning/debts/${debt.id}/edit'),
          onPay: (debt) => context.push('/planning/debts/${debt.id}/pay'),
          onCancel: (debt) => _cancel(context, debt),
        ),
        AsyncError(:final error) => _ErrorView(
          error: error,
          onRetry: () => ref.invalidate(debtsProvider),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Future<void> _cancel(BuildContext context, Debt debt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancelar dívida?'),
        content: Text(
          '«${debt.description}» sai da lista de pendentes. '
          'Pagamentos já feitos mantêm os movimentos reais.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancelar dívida'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(debtRepositoryProvider).cancel(debt.id);
      messenger.showSnackBar(
        const SnackBar(content: Text('Dívida cancelada.')),
      );
    } on AppFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }
}

class _DebtsList extends StatelessWidget {
  const _DebtsList({
    required this.debts,
    required this.onEdit,
    required this.onPay,
    required this.onCancel,
  });

  final List<Debt> debts;
  final ValueChanged<Debt> onEdit;
  final ValueChanged<Debt> onPay;
  final ValueChanged<Debt> onCancel;

  @override
  Widget build(BuildContext context) {
    if (debts.isEmpty) {
      return EmptyState(
        icon: Icons.check_circle_outline,
        title: 'Sem dívidas em aberto',
        message: 'Ativa o filtro para ver as dívidas liquidadas.',
      );
    }
    final payable = debts
        .where((debt) => debt.kind == DebtKind.payable && debt.isOpen)
        .fold(0, (total, debt) => total + debt.remaining);
    final receivable = debts
        .where((debt) => debt.kind == DebtKind.receivable && debt.isOpen)
        .fold(0, (total, debt) => total + debt.remaining);
    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        if (payable > 0 || receivable > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'A pagar ${MoneyFormatter.formatXof(payable)} · '
              'A receber ${MoneyFormatter.formatXof(receivable)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        for (final debt in debts)
          _DebtTile(
            debt: debt,
            onEdit: () => onEdit(debt),
            onPay: () => onPay(debt),
            onCancel: () => onCancel(debt),
          ),
      ],
    );
  }
}

class _DebtTile extends StatelessWidget {
  const _DebtTile({
    required this.debt,
    required this.onEdit,
    required this.onPay,
    required this.onCancel,
  });

  final Debt debt;
  final VoidCallback onEdit;
  final VoidCallback onPay;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = <String>[
      if (debt.counterparty != null) debt.counterparty!,
      if (debt.dueDate != null) 'vence ${formatDate(debt.dueDate!)}',
      debt.effectiveStatus.label,
      if (debt.paidTotal > 0)
        'pago ${MoneyFormatter.formatXof(debt.paidTotal)}',
    ].join(' · ');
    return ListTile(
      leading: CircleAvatar(
        child: Icon(
          debt.kind == DebtKind.payable ? Icons.call_made : Icons.call_received,
        ),
      ),
      title: Text('${debt.description} · ${debt.kind.label}'),
      subtitle: Text(details),
      isThreeLine: details.length > 40,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            MoneyFormatter.formatXof(debt.remaining),
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (debt.isOpen)
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
                PopupMenuItem(value: 'pay', child: Text('Registar pagamento')),
                PopupMenuItem(value: 'cancel', child: Text('Cancelar dívida')),
              ],
            ),
        ],
      ),
      onTap: debt.isOpen ? onEdit : null,
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
        : 'Não foi possível carregar as dívidas.';
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
