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
              AsyncData(:final value) => _GroupedMovementsList(
                items: value.items,
                onEdit: (item) =>
                    context.push('/movements/${item.movement.id}/edit'),
                onDelete: (item) => _delete(context, ref, item.movement),
              ),
              AsyncError(:final error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
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

sealed class _MovementRowData {
  const _MovementRowData();
}

class _DayRowData extends _MovementRowData {
  const _DayRowData({required this.date, required this.items});

  final DateTime date;
  final List<MovementListItem> items;
}

class _ItemRowData extends _MovementRowData {
  const _ItemRowData(this.item);

  final MovementListItem item;
}

class _GroupedMovementsList extends StatelessWidget {
  const _GroupedMovementsList({
    required this.items,
    required this.onEdit,
    required this.onDelete,
  });

  final List<MovementListItem> items;
  final ValueChanged<MovementListItem> onEdit;
  final ValueChanged<MovementListItem> onDelete;

  List<_MovementRowData> _rows() {
    final rows = <_MovementRowData>[];
    _DayRowData? day;
    DateTime? lastDate;
    for (final item in items) {
      final date = FinancialDate.dateOnly(item.movement.date);
      if (day == null || date != lastDate) {
        day = _DayRowData(date: date, items: []);
        rows.add(day);
        lastDate = date;
      }
      day.items.add(item);
      rows.add(_ItemRowData(item));
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows();
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        return switch (row) {
          _DayRowData(:final date, :final items) => _DayHeader(
            date: date,
            items: items,
          ),
          _ItemRowData(:final item) => _MovementTile(
            item: item,
            onEdit: () => onEdit(item),
            onDelete: () => onDelete(item),
          ),
        };
      },
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.date, required this.items});

  final DateTime date;
  final List<MovementListItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final income = items
        .where((item) => item.movement.kind == MovementKind.income)
        .fold(0, (total, item) => total + item.movement.amount);
    final expense = items
        .where((item) => item.movement.kind == MovementKind.expense)
        .fold(0, (total, item) => total + item.movement.amount);
    final net = income - expense;
    return Container(
      color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.7),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Text(
            FinancialDate.toDisplay(FinancialDate.fromDateTime(date)),
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            PluralFormatter.count(items.length, 'movimento', 'movimentos'),
            style: theme.textTheme.bodySmall,
          ),
          const Spacer(),
          if (net != 0)
            MoneyText(
              net,
              signed: true,
              tone: net > 0 ? MoneyTone.income : MoneyTone.expense,
              style: theme.textTheme.labelMedium,
            ),
        ],
      ),
    );
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
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        0,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.sm,
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
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: _TotalChip(
              label: 'Rendimentos',
              value: totals.income,
              tone: MoneyTone.income,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _TotalChip(
              label: 'Despesas',
              value: totals.expense,
              tone: MoneyTone.expense,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            PluralFormatter.count(count, 'registo', 'registos'),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _TotalChip extends StatelessWidget {
  const _TotalChip({
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final int value;
  final MoneyTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: AppRadii.control,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.labelSmall),
            const SizedBox(height: AppSpacing.xxs),
            MoneyText(
              value,
              compact: true,
              tone: tone,
              style: theme.textTheme.titleSmall,
              semanticsLabel: '$label: ${MoneyFormatter.formatXof(value)}',
            ),
          ],
        ),
      ),
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
    final finance = FinanceColors.of(context);
    final movement = item.movement;
    final tone = switch (movement.kind) {
      MovementKind.income => MoneyTone.income,
      MovementKind.expense => MoneyTone.expense,
      MovementKind.transfer => MoneyTone.transfer,
    };
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
    final details = movement.kind.isTransfer
        ? '${item.accountName} → ${item.destinationAccountName ?? ''}'
        : [
            if (item.categoryName != null) item.categoryName!,
            item.accountName,
          ].join(' · ');

    return InkWell(
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
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
              child: Semantics(
                container: true,
                label:
                    '${movement.kind.label}: $title, $details, '
                    '${FinancialDate.toDisplay(FinancialDate.fromDateTime(movement.date))}.',
                child: ExcludeSemantics(
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 132),
              child: MoneyText(
                movement.kind == MovementKind.expense
                    ? -movement.amount
                    : movement.amount,
                signed: !movement.kind.isTransfer,
                tone: tone,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
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
              constraints: const BoxConstraints(minWidth: 160),
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
      ),
    );
  }
}
