import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/empty_state.dart';
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
        AsyncData(:final value) when value.isEmpty => const EmptyState(
          icon: Icons.category_outlined,
          title: 'Sem categorias',
          message: 'Cria uma categoria de rendimento ou despesa.',
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
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        if (income.isNotEmpty) const _SectionHeader('Rendimentos'),
        for (final category in income)
          _CategoryTile(
            category: category,
            onEdit: () => onEdit(category),
            onToggleArchive: () => onToggleArchive(category),
          ),
        if (expense.isNotEmpty) const _SectionHeader('Despesas'),
        for (final category in expense)
          _CategoryTile(
            category: category,
            onEdit: () => onEdit(category),
            onToggleArchive: () => onToggleArchive(category),
          ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(title, style: Theme.of(context).textTheme.titleSmall),
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
    final subtitle = <String>[
      category.isSystem ? 'Predefinida' : 'Personalizada',
      if (category.isArchived) 'Arquivada',
    ].join(' · ');
    return ListTile(
      leading: Icon(
        category.kind == CategoryKind.income
            ? Icons.trending_up
            : Icons.trending_down,
      ),
      title: Text(category.name),
      subtitle: Text(subtitle),
      trailing: PopupMenuButton<String>(
        tooltip: 'Opções',
        onSelected: (_) => onToggleArchive(),
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'archive',
            child: Text(
              category.isArchived ? 'Reativar categoria' : 'Arquivar categoria',
            ),
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
