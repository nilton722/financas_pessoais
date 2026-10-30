import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../data/transaction_repository.dart';
import '../domain/movement.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>(
  (ref) => TransactionRepository(ref.watch(appDatabaseProvider)),
);

class MovementFilterController extends Notifier<MovementFilter> {
  @override
  MovementFilter build() => const MovementFilter();

  void setKind(MovementKind? kind) => state = MovementFilter(
    from: state.from,
    to: state.to,
    accountId: state.accountId,
    kind: kind,
    categoryId: kind?.isTransfer ?? false ? null : state.categoryId,
  );

  void setAccount(String? accountId) => state = MovementFilter(
    from: state.from,
    to: state.to,
    accountId: accountId,
    kind: state.kind,
    categoryId: state.categoryId,
  );

  void setCategory(String? categoryId) => state = MovementFilter(
    from: state.from,
    to: state.to,
    accountId: state.accountId,
    kind: state.kind,
    categoryId: categoryId,
  );

  void setRange(DateTime? from, DateTime? to) => state = MovementFilter(
    from: from,
    to: to,
    accountId: state.accountId,
    kind: state.kind,
    categoryId: state.categoryId,
  );

  void clear() => state = const MovementFilter();
}

final movementFilterProvider =
    NotifierProvider<MovementFilterController, MovementFilter>(
      MovementFilterController.new,
    );

final movementListProvider =
    StreamProvider.family<MovementListResult, MovementFilter>((ref, filter) {
      return ref
          .watch(transactionRepositoryProvider)
          .watchMovements(filter)
          .map(
            (items) => MovementListResult(
              items: items,
              totals: MovementTotals.of(items.map((item) => item.movement)),
            ),
          );
    });

final movementByIdProvider = FutureProvider.family<Movement?, String>(
  (ref, id) => ref.watch(transactionRepositoryProvider).findById(id),
);
