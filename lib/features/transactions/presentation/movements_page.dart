import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/formatters/date_formatter.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/widgets/empty_state.dart';
import '../../accounts/domain/account.dart';
import '../../accounts/presentation/accounts_providers.dart';
import '../../categories/domain/category.dart';
import '../../categories/presentation/categories_providers.dart';
import '../domain/movement.dart';
import 'transactions_providers.dart';

class MovementsPage extends ConsumerWidget {
  const MovementsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(movementFilterProvider);
    final controller = ref.read(movementFilterProvider.notifier);
    final result = ref.watch(movementListProvider(filter));
    final accounts = ref.watch(allAccountsProvider).value ?? const <Account>[];
    final categoryKind = switch (filter.kind) {
      MovementKind.income => CategoryKind.income,
      MovementKind.expense => CategoryKind.expense,
      _ => null,
    };
    final categories =
        ref.watch(allCategoriesProvider(categoryKind)).value ??
        const <Category>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Movimentos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/movements/new'),
        icon: const Icon(Icons.add),
        label: const Text('Novo movimento'),
      ),
      body: Column(
        children: [
          _FilterBar(
            filter: filter,
            accounts: accounts,
            categories: categories,
            onKindChanged: controller.setKind,
            onAccountChanged: controller.setAccount,
            onCategoryChanged: controller.setCategory,
            onRangePicked: (range) =>
                controller.setRange(range?.start, range?.end),
            onClear: controller.clear,
          ),
          _TotalsBar(
            totals: result.value?.totals ?? MovementTotals.zero,
            count: result.value?.items.length ?? 0,
          ),
          Expanded(
            child: switch (result) {
              AsyncData(:final value) when value.items.isEmpty =>
                const EmptyState(
                  icon: Icons.swap_vert,
                  title: 'Sem movimentos',
                  message: 'Ajusta os filtros ou registra um novo movimento.',
                ),
              AsyncData(:final value) => ListView.separated(
                padding: const EdgeInsets.only(bottom: 96),
                itemCount: value.items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = value.items[index];
                  return _MovementTile(
                    item: item,
                    onEdit: () =>
                        context.push('/movements/${item.movement.id}/edit'),
                    onDelete: () => _delete(context, ref, item.movement),
                  );
                },
              ),
              AsyncError(:final error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    error is AppFailure
                        ? error.message
                        : 'Não foi possível carregar os movimentos.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
        ],
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Movement movement,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar movimento?'),
        content: const Text(
          'O movimento deixa de contar para saldos e relatórios. '
          'A operação não pode ser desfeita na interface.',
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
      await ref.read(transactionRepositoryProvider).softDelete(movement.id);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Movimento eliminado. Saldos atualizados.'),
        ),
      );
    } on AppFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filter,
    required this.accounts,
    required this.categories,
    required this.onKindChanged,
    required this.onAccountChanged,
    required this.onCategoryChanged,
    required this.onRangePicked,
    required this.onClear,
  });

  final MovementFilter filter;
  final List<Account> accounts;
  final List<Category> categories;
  final ValueChanged<MovementKind?> onKindChanged;
  final ValueChanged<String?> onAccountChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<DateTimeRange?> onRangePicked;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final rangeLabel = filter.from == null || filter.to == null
        ? 'Período'
        : '${FinancialDate.toDisplay(FinancialDate.fromDateTime(filter.from!))}'
              ' – ${FinancialDate.toDisplay(FinancialDate.fromDateTime(filter.to!))}';
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _FilterDropdown<MovementKind>(
              label: 'Tipo',
              value: filter.kind,
              items: [
                const DropdownMenuItem(value: null, child: Text('Todos')),
                for (final kind in MovementKind.values)
                  DropdownMenuItem(value: kind, child: Text(kind.label)),
              ],
              onChanged: onKindChanged,
            ),
            _FilterDropdown<String>(
              label: 'Conta',
              value: filter.accountId,
              items: [
                const DropdownMenuItem(value: null, child: Text('Todas')),
                for (final account in accounts)
                  DropdownMenuItem(
                    value: account.id,
                    child: Text(account.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: onAccountChanged,
            ),
            if (!(filter.kind?.isTransfer ?? false))
              _FilterDropdown<String>(
                label: 'Categoria',
                value: filter.categoryId,
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todas')),
                  for (final category in categories)
                    DropdownMenuItem(
                      value: category.id,
                      child: Text(
                        category.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: onCategoryChanged,
              ),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(1990),
                  lastDate: FinancialDate.today(),
                  initialDateRange: filter.from != null && filter.to != null
                      ? DateTimeRange(start: filter.from!, end: filter.to!)
                      : null,
                  helpText: 'Período',
                );
                onRangePicked(picked);
              },
              icon: const Icon(Icons.date_range_outlined),
              label: Text(rangeLabel),
            ),
            if (filter.isActive)
              TextButton(onPressed: onClear, child: const Text('Limpar')),
          ],
        ),
      ),
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T?>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        SizedBox(
          width: 160,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T?>(
              value: value,
              isDense: true,
              // O botão mede-se pelo item mais largo; sem `isExpanded` a Row
              // interna excede os 160 px quando uma categoria tem nome longo.
              isExpanded: true,
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _TotalsBar extends StatelessWidget {
  const _TotalsBar({required this.totals, required this.count});

  final MovementTotals totals;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          _Total(label: 'Rendimentos', value: totals.income, theme: theme),
          const SizedBox(width: 16),
          _Total(label: 'Despesas', value: totals.expense, theme: theme),
          const Spacer(),
          Text(
            '$count ${count == 1 ? 'registo' : 'registos'}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.label, required this.value, required this.theme});

  final String label;
  final int value;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelSmall),
        Text(
          MoneyFormatter.formatXof(value),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final MovementListItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final movement = item.movement;
    final isDark = theme.brightness == Brightness.dark;
    final color = switch (movement.kind) {
      MovementKind.income =>
        isDark ? Colors.green.shade300 : Colors.green.shade700,
      MovementKind.expense => theme.colorScheme.error,
      MovementKind.transfer => theme.colorScheme.primary,
    };
    final icon = switch (movement.kind) {
      MovementKind.income => Icons.add_circle_outline,
      MovementKind.expense => Icons.remove_circle_outline,
      MovementKind.transfer => Icons.swap_horiz,
    };
    final title =
        movement.description ??
        item.categoryName ??
        (movement.kind.isTransfer ? 'Transferência' : 'Sem descrição');
    final date = FinancialDate.toDisplay(
      FinancialDate.fromDateTime(movement.date),
    );
    final subtitle = movement.kind.isTransfer
        ? '$date · ${item.accountName} → ${item.destinationAccountName ?? ''}'
        : '$date · ${item.accountName}';
    final amount = switch (movement.kind) {
      MovementKind.income => '+${MoneyFormatter.formatXof(movement.amount)}',
      MovementKind.expense => '-${MoneyFormatter.formatXof(movement.amount)}',
      MovementKind.transfer => MoneyFormatter.formatXof(movement.amount),
    };

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            amount,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Opções',
            onSelected: (value) {
              if (value == 'edit') {
                onEdit();
              } else if (value == 'delete') {
                onDelete();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Editar')),
              PopupMenuItem(value: 'delete', child: Text('Eliminar')),
            ],
          ),
        ],
      ),
      onTap: onEdit,
    );
  }
}
