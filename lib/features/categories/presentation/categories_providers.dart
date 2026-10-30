import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../data/category_repository.dart';
import '../domain/category.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => CategoryRepository(ref.watch(appDatabaseProvider)),
);

class ShowArchivedCategories extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final showArchivedCategoriesProvider =
    NotifierProvider<ShowArchivedCategories, bool>(ShowArchivedCategories.new);

final categoryListProvider =
    StreamProvider.family<List<Category>, CategoryKind?>((ref, kind) {
      final includeArchived = ref.watch(showArchivedCategoriesProvider);
      return ref
          .watch(categoryRepositoryProvider)
          .watchAll(includeArchived: includeArchived, kind: kind);
    });

final activeCategoriesProvider =
    StreamProvider.family<List<Category>, CategoryKind>(
      (ref, kind) => ref.watch(categoryRepositoryProvider).watchAll(kind: kind),
    );

/// Inclui arquivadas (para edição de movimentos antigos e para o filtro).
final allCategoriesProvider =
    StreamProvider.family<List<Category>, CategoryKind?>(
      (ref, kind) => ref
          .watch(categoryRepositoryProvider)
          .watchAll(includeArchived: true, kind: kind),
    );
