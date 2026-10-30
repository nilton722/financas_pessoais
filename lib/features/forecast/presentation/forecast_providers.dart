import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../../../core/formatters/date_formatter.dart';
import '../../accounts/presentation/accounts_providers.dart';
import '../../planning/presentation/planning_providers.dart';
import '../data/forecast_repository.dart';
import '../domain/forecast.dart';

final forecastRepositoryProvider = Provider<ForecastRepository>(
  (ref) => ForecastRepository(ref.watch(appDatabaseProvider)),
);

/// Previsão a partir dos mesmos streams que alimentam o painel e o
/// planeamento: alterações a saldos, compromissos ou recorrências provocam um
/// novo cálculo. A sincronização interna de ocorrências é idempotente, pelo
/// que o recálculo seguinte não volta a escrever.
final forecastBundleProvider = FutureProvider<ForecastBundle>((ref) async {
  await ref.watch(accountBalancesProvider.future);
  await ref.watch(pendingPlannedItemsProvider.future);
  return ref
      .watch(forecastRepositoryProvider)
      .buildBundle(cutoff: FinancialDate.today());
});
