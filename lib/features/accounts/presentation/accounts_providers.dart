import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../data/account_repository.dart';
import '../domain/account.dart';
import '../domain/account_balance.dart';

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => AccountRepository(ref.watch(appDatabaseProvider)),
);

class ShowArchivedAccounts extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final showArchivedAccountsProvider =
    NotifierProvider<ShowArchivedAccounts, bool>(ShowArchivedAccounts.new);

final accountListProvider = StreamProvider<List<Account>>((ref) {
  final includeArchived = ref.watch(showArchivedAccountsProvider);
  return ref
      .watch(accountRepositoryProvider)
      .watchAll(includeArchived: includeArchived);
});

final activeAccountsProvider = StreamProvider<List<Account>>(
  (ref) => ref.watch(accountRepositoryProvider).watchAll(),
);

/// Inclui arquivadas para que formulários de edição consigam mostrar a conta
/// já associada a um movimento antigo.
final allAccountsProvider = StreamProvider<List<Account>>(
  (ref) => ref.watch(accountRepositoryProvider).watchAll(includeArchived: true),
);

final accountBalancesProvider = StreamProvider<List<AccountBalance>>((ref) {
  final includeArchived = ref.watch(showArchivedAccountsProvider);
  return ref
      .watch(accountRepositoryProvider)
      .watchBalances(until: DateTime.now(), includeArchived: includeArchived);
});
