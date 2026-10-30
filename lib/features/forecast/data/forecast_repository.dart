import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart' as db;
import '../../../core/formatters/date_formatter.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/domain/account_balance.dart';
import '../../planning/data/planning_repository.dart';
import '../../planning/domain/planned_item.dart';
import '../../settings/data/app_settings_repository.dart';
import '../domain/forecast.dart';

/// Junta os dados que o motor de previsão consome. Não calcula regras
/// financeiras: saldos, compromissos e histórico vêm dos repositórios já
/// existentes, para que exista uma única definição de cada regra.
class ForecastRepository {
  ForecastRepository(this._db);

  final db.AppDatabase _db;

  /// Materializa as ocorrências recorrentes até ao maior horizonte pedido,
  /// para que cada uma entre na previsão exatamente uma vez. A sincronização
  /// é idempotente e cria compromissos planeados, nunca movimentos reais.
  Future<ForecastRequest> buildRequest({
    required DateTime cutoff,
    ForecastParameters parameters = const ForecastParameters(),
  }) async {
    final cutoffDate = FinancialDate.dateOnly(cutoff);
    final planning = PlanningRepository(_db);
    final syncDays = parameters.horizonDays > forecastMaxHorizonDays
        ? parameters.horizonDays
        : forecastMaxHorizonDays;
    await planning.syncRecurrences(
      horizon: cutoffDate.add(Duration(days: syncDays)),
    );

    final settings = await AppSettingsRepository(_db).load();
    final balances = await AccountRepository(_db)
        .readBalances(until: cutoffDate);
    final openingBalance = consolidatedBalance(
      balances,
      currencyCode: settings.currencyCode,
    );

    final items = await planning.readItems(pendingOnly: true);
    final commitments = <ForecastCommitment>[
      for (final item in items)
        if (item.remaining > 0)
          ForecastCommitment(
            id: item.id,
            flow: item.kind == PlannedItemKind.income
                ? ForecastFlow.inflow
                : ForecastFlow.outflow,
            amount: item.remaining,
            dueDate: item.dueDate,
            description: item.description,
            categoryId: item.categoryId,
            categoryName: item.categoryName,
          ),
    ];

    final history = await _readHistory(
      cutoff: cutoffDate,
      historyMonths: parameters.historyMonths,
    );

    return ForecastRequest(
      cutoff: cutoffDate,
      openingBalance: openingBalance,
      commitments: commitments,
      history: history,
      parameters: parameters,
    );
  }

  /// Calcula os três horizontes sobre a mesma fotografia. O resultado inclui a
  /// data de corte, os parâmetros e a versão do algoritmo, pelo que continua
  /// reproduzível sem guardar snapshots.
  Future<ForecastBundle> buildBundle({
    required DateTime cutoff,
    DateTime? generatedAt,
  }) async {
    final parameters = const ForecastParameters(
      horizonDays: forecastMaxHorizonDays,
    );
    final base = await buildRequest(cutoff: cutoff, parameters: parameters);
    const engine = ForecastEngine();
    final results = <int, ForecastResult>{};
    for (final horizon in forecastHorizons) {
      results[horizon] = engine.run(
        base.copyWith(parameters: parameters.copyWith(horizonDays: horizon)),
      );
    }
    return ForecastBundle(
      cutoff: FinancialDate.dateOnly(cutoff),
      generatedAt: generatedAt ?? DateTime.now().toUtc(),
      results: results,
    );
  }

  /// Despesas não eliminadas dos meses completos anteriores à data de corte.
  /// Rendimentos e transferências ficam de fora: só despesas servem de base
  /// às estimativas históricas.
  Future<List<ForecastHistoryEntry>> _readHistory({
    required DateTime cutoff,
    required int historyMonths,
  }) async {
    if (historyMonths <= 0) {
      return const [];
    }
    final start = DateTime(cutoff.year, cutoff.month - historyMonths);
    final end = DateTime(cutoff.year, cutoff.month);
    const sql = '''
SELECT t.transaction_date, t.category_id, t.amount,
       c.name AS category_name
FROM transactions t
LEFT JOIN categories c ON c.id = t.category_id
WHERE t.deleted_at IS NULL
  AND t.kind = 'expense'
  AND t.transaction_date >= ?
  AND t.transaction_date < ?
ORDER BY t.transaction_date ASC, t.created_at ASC
''';
    final rows = await _db
        .customSelect(
          sql,
          variables: [
            Variable.withString(FinancialDate.fromDateTime(start)),
            Variable.withString(FinancialDate.fromDateTime(end)),
          ],
        )
        .get();
    return [
      for (final row in rows)
        ForecastHistoryEntry(
          date:
              FinancialDate.tryParse(row.read<String>('transaction_date')) ??
              start,
          amount: row.read<int>('amount'),
          categoryId: row.readNullable<String>('category_id'),
          categoryName: row.readNullable<String>('category_name'),
        ),
    ];
  }
}
