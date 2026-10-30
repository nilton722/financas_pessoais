import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../domain/category.dart';
import 'categories_providers.dart';

class CategoriesPage extends ConsumerWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoryListProvider(null));
    final showArchived = ref.watch(showArchivedCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorias'),
        actions: [
          IconButton(
            tooltip: showArchived ? 'Ocultar arquivadas' : 'Mostrar arquivadas',
            icon: Icon(
              showArchived
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
            onPressed: () =>
                ref.read(showArchivedCategoriesProvider.notifier).toggle(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/categories/new'),
        icon: const Icon(Icons.add),
        label: const Text('Nova categoria'),
      ),
      body: switch (categories) {
        AsyncData(:final value) when value.isEmpty => Center(
          child: SingleChildScrollView(
            padding: AppSpacing.page,
            child: EmptyState(
              icon: Icons.category_outlined,
              title: 'Sem categorias',
              message: 'Cria uma categoria de rendimento ou despesa.',
              action: FilledButton.icon(
                onPressed: () => context.push('/categories/new'),
                icon: const Icon(Icons.add),
                label: const Text('Nova categoria'),
              ),
            ),
          ),
        ),
        AsyncData(:final value) => _CategoryList(
          categories: value,
          onEdit: (category) => context.push('/categories/${category.id}/edit'),
          onToggleArchive: (category) => _toggleArchive(context, ref, category),
        ),
        AsyncError(:final error) => _ErrorView(
          error: error,
          onRetry: () => ref.invalidate(categoryListProvider(null)),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Future<void> _toggleArchive(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!category.isArchived) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Arquivar categoria?'),
          content: Text(
            '«${category.name}» deixa de aparecer em novos movimentos. '
            'Os movimentos existentes mantêm a categoria.',
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
          .read(categoryRepositoryProvider)
          .setArchived(category.id, archived: !category.isArchived);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            category.isArchived
                ? 'Categoria reativada.'
                : 'Categoria arquivada.',
          ),
        ),
      );
    } on AppFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({
    required this.categories,
    required this.onEdit,
    required this.onToggleArchive,
  });

  final List<Category> categories;
  final ValueChanged<Category> onEdit;
  final ValueChanged<Category> onToggleArchive;

  @override
  Widget build(BuildContext context) {
    final income = categories
        .where((category) => category.kind == CategoryKind.income)
        .toList();
    final expense = categories
        .where((category) => category.kind == CategoryKind.expense)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xxl + AppSpacing.xxxl,
      ),
      children: [
        if (income.isNotEmpty) ...[
          SectionCard(
            title: 'Rendimentos',
            padding: EdgeInsets.zero,
            divider: true,
            child: Column(
              children: [
                for (final category in income) ...[
                  _CategoryTile(
                    category: category,
                    onEdit: () => onEdit(category),
                    onToggleArchive: () => onToggleArchive(category),
                  ),
                  if (category != income.last) const Divider(height: 1),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (expense.isNotEmpty)
          SectionCard(
            title: 'Despesas',
            padding: EdgeInsets.zero,
            divider: true,
            child: Column(
              children: [
                for (final category in expense) ...[
                  _CategoryTile(
                    category: category,
                    onEdit: () => onEdit(category),
                    onToggleArchive: () => onToggleArchive(category),
                  ),
                  if (category != expense.last) const Divider(height: 1),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.onEdit,
    required this.onToggleArchive,
  });

  final Category category;
  final VoidCallback onEdit;
  final VoidCallback onToggleArchive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final income = category.kind == CategoryKind.income;
    return ListTile(
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
      title: Text(category.name),
      subtitle: Text(category.isSystem ? 'Predefinida' : 'Personalizada'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (category.isArchived) ...[
            const StatusBadge('Arquivada'),
            const SizedBox(width: AppSpacing.xs),
          ],
          PopupMenuButton<String>(
            tooltip: 'Opções',
            onSelected: (_) => onToggleArchive(),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'archive',
                child: Text(
                  category.isArchived
                      ? 'Reativar categoria'
                      : 'Arquivar categoria',
                ),
              ),
            ],
          ),
        ],
      ),
      onTap: onEdit,
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
        : 'Não foi possível carregar as categorias.';
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
