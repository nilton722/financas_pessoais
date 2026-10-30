import '../../../core/formatters/date_formatter.dart';
import '../../../core/formatters/money_formatter.dart';

/// Versão explícita do algoritmo. Entra no resultado e na interface para que
/// duas previsões possam ser comparadas sabendo como foram calculadas.
const String forecastAlgorithmVersion = 'forecast-1';

/// Horizontes mostrados na interface. O motor aceita qualquer horizonte
/// positivo; estes são os que a app apresenta e materializa.
const List<int> forecastHorizons = [7, 30, 90];

/// Maior horizonte usado para materializar ocorrências recorrentes.
const int forecastMaxHorizonDays = 90;

enum ForecastFlow {
  inflow('Rendimento'),
  outflow('Despesa');

  const ForecastFlow(this.label);

  final String label;
}

/// Parâmetros explícitos e testáveis. A suficiência do histórico é uma
/// decisão de produto: três meses completos com despesas, pelo menos seis
/// despesas no total e uma categoria presente em dois meses.
class ForecastParameters {
  const ForecastParameters({
    this.horizonDays = 30,
    this.historyMonths = 3,
    this.minMonthsWithExpenses = 3,
    this.minExpenseMovements = 6,
    this.minCategoryMonths = 2,
    this.useHistoricalEstimates = true,
  });

  final int horizonDays;
  final int historyMonths;
  final int minMonthsWithExpenses;
  final int minExpenseMovements;
  final int minCategoryMonths;
  final bool useHistoricalEstimates;

  ForecastParameters copyWith({int? horizonDays}) => ForecastParameters(
    horizonDays: horizonDays ?? this.horizonDays,
    historyMonths: historyMonths,
    minMonthsWithExpenses: minMonthsWithExpenses,
    minExpenseMovements: minExpenseMovements,
    minCategoryMonths: minCategoryMonths,
    useHistoricalEstimates: useHistoricalEstimates,
  );
}

/// Compromisso conhecido, já líquido do que foi pago. Só o restante entra na
/// previsão; o valor já pago faz parte do saldo de partida.
class ForecastCommitment {
  const ForecastCommitment({
    required this.id,
    required this.flow,
    required this.amount,
    required this.dueDate,
    required this.description,
    this.categoryId,
    this.categoryName,
  });

  final String id;
  final ForecastFlow flow;
  final int amount;
  final DateTime dueDate;
  final String description;
  final String? categoryId;
  final String? categoryName;

  int get signedAmount => flow == ForecastFlow.inflow ? amount : -amount;
}

/// Despesa realizada num mês completo anterior à data de corte. Transferências
/// e rendimentos nunca chegam aqui.
class ForecastHistoryEntry {
  const ForecastHistoryEntry({
    required this.date,
    required this.amount,
    this.categoryId,
    this.categoryName,
  });

  final DateTime date;
  final int amount;
  final String? categoryId;
  final String? categoryName;
}

class ForecastRequest {
  const ForecastRequest({
    required this.cutoff,
    required this.openingBalance,
    this.commitments = const [],
    this.history = const [],
    this.parameters = const ForecastParameters(),
  });

  final DateTime cutoff;
  final int openingBalance;
  final List<ForecastCommitment> commitments;
  final List<ForecastHistoryEntry> history;
  final ForecastParameters parameters;

  ForecastRequest copyWith({ForecastParameters? parameters}) => ForecastRequest(
    cutoff: cutoff,
    openingBalance: openingBalance,
    commitments: commitments,
    history: history,
    parameters: parameters ?? this.parameters,
  );
}

/// Linha de compromisso confirmado dentro do horizonte, já com a data efetiva
/// (vencidos contam na data de corte).
class ForecastMovementLine {
  const ForecastMovementLine({
    required this.date,
    required this.description,
    required this.amount,
    required this.isEstimate,
    this.categoryName,
  });

  final DateTime date;
  final String description;
  final int amount;
  final bool isEstimate;
  final String? categoryName;

  bool get isInflow => amount >= 0;
}

class ForecastDay {
  const ForecastDay({
    required this.date,
    required this.openingBalance,
    required this.confirmedDelta,
    required this.estimatedDelta,
    required this.closingBalance,
  });

  final DateTime date;
  final int openingBalance;

  /// Efeito líquido dos compromissos confirmados no dia.
  final int confirmedDelta;

  /// Efeito líquido das despesas históricas estimadas no dia.
  final int estimatedDelta;

  final int closingBalance;

  int get totalDelta => confirmedDelta + estimatedDelta;

  bool get isNegative => closingBalance < 0;
}

class ForecastDataQuality {
  const ForecastDataQuality({
    required this.historySufficient,
    required this.monthsWithExpenses,
    required this.expenseMovements,
    required this.estimatedCategories,
    required this.estimatedMonthlyTotal,
    required this.limitations,
  });

  final bool historySufficient;
  final int monthsWithExpenses;
  final int expenseMovements;
  final int estimatedCategories;

  /// Soma das medianas mensais efetivamente usadas (após exclusões por
  /// compromissos conhecidos).
  final int estimatedMonthlyTotal;
  final List<String> limitations;

  String get summary => historySufficient
      ? 'Histórico suficiente: $monthsWithExpenses meses com despesas e '
            '$expenseMovements despesas analisadas; '
            '$estimatedCategories ${estimatedCategories == 1 ? 'categoria estimada' : 'categorias estimadas'}.'
      : 'Histórico insuficiente: $monthsWithExpenses meses com despesas e '
            '$expenseMovements despesas. A projeção usa apenas compromissos '
            'conhecidos.';
}

class ForecastResult {
  const ForecastResult({
    required this.cutoff,
    required this.endDate,
    required this.openingBalance,
    required this.days,
    required this.commitments,
    required this.closingBalance,
    required this.lowestBalance,
    required this.lowestDate,
    required this.confirmedNet,
    required this.estimatedNet,
    required this.quality,
    required this.assumptions,
    required this.parameters,
  });

  final DateTime cutoff;
  final DateTime endDate;
  final int openingBalance;
  final List<ForecastDay> days;

  /// Compromissos confirmados dentro do horizonte, ordenados por data.
  final List<ForecastMovementLine> commitments;

  final int closingBalance;
  final int lowestBalance;
  final DateTime lowestDate;
  final int confirmedNet;
  final int estimatedNet;
  final ForecastDataQuality quality;
  final List<String> assumptions;
  final ForecastParameters parameters;

  int get horizonDays => parameters.horizonDays;

  bool get hasNegativeBalance => lowestBalance < 0;

  DateTime? get firstNegativeDate {
    for (final day in days) {
      if (day.isNegative) {
        return day.date;
      }
    }
    return null;
  }

  int get commitmentTotal =>
      commitments.fold(0, (total, line) => total + line.amount);
}

/// Resultados para os três horizontes calculados sobre a mesma fotografia de
/// dados e os mesmos parâmetros.
class ForecastBundle {
  const ForecastBundle({
    required this.cutoff,
    required this.generatedAt,
    required this.results,
  });

  final DateTime cutoff;
  final DateTime generatedAt;
  final Map<int, ForecastResult> results;

  ForecastResult resultFor(int horizon) {
    final result = results[horizon];
    if (result == null) {
      throw ArgumentError.value(horizon, 'horizon', 'Horizonte não calculado');
    }
    return result;
  }
}

/// Motor determinístico: os mesmos dados produzem sempre o mesmo resultado.
/// Não lê a base, não faz chamadas de rede e não usa aleatoriedade.
class ForecastEngine {
  const ForecastEngine();

  ForecastResult run(ForecastRequest request) {
    final cutoff = FinancialDate.dateOnly(request.cutoff);
    final parameters = request.parameters;
    final horizon = parameters.horizonDays < 0 ? 0 : parameters.horizonDays;
    final endDate = cutoff.add(Duration(days: horizon));

    final analysis = _HistoryAnalysis.compute(
      history: request.history,
      cutoff: cutoff,
      parameters: parameters,
    );

    final confirmedByDate = <DateTime, int>{};
    final commitmentLines = <ForecastMovementLine>[];
    final commitmentCategories = <String>{};
    var hasUncategorizedCommitment = false;
    for (final commitment in request.commitments) {
      if (commitment.amount <= 0) {
        continue;
      }
      final due = FinancialDate.dateOnly(commitment.dueDate);
      final effective = due.isBefore(cutoff) ? cutoff : due;
      if (effective.isAfter(endDate)) {
        continue;
      }
      confirmedByDate.update(
        effective,
        (value) => value + commitment.signedAmount,
        ifAbsent: () => commitment.signedAmount,
      );
      commitmentLines.add(
        ForecastMovementLine(
          date: effective,
          description: commitment.description,
          amount: commitment.signedAmount,
          isEstimate: false,
          categoryName: commitment.categoryName,
        ),
      );
      final categoryId = commitment.categoryId;
      if (categoryId == null || categoryId.isEmpty) {
        hasUncategorizedCommitment = true;
      } else {
        commitmentCategories.add(categoryId);
      }
    }
    commitmentLines.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      if (byDate != 0) {
        return byDate;
      }
      return a.description.compareTo(b.description);
    });

    final estimates = parameters.useHistoricalEstimates
        ? analysis.estimatesExcluding(commitmentCategories)
        : const <String, _CategoryEstimate>{};

    final days = <ForecastDay>[];
    var balance = request.openingBalance;
    var lowestBalance = balance;
    var lowestDate = cutoff;
    var confirmedNet = 0;
    var estimatedNet = 0;

    for (var offset = 0; offset <= horizon; offset++) {
      final date = cutoff.add(Duration(days: offset));
      final opening = balance;
      final confirmed = confirmedByDate[date] ?? 0;
      // No dia de corte as estimativas ainda não se aplicam: esse dia está
      // refletido no saldo real.
      final estimated = offset == 0 ? 0 : _estimatedExpenseFor(date, estimates);
      final closing = opening + confirmed + estimated;
      days.add(
        ForecastDay(
          date: date,
          openingBalance: opening,
          confirmedDelta: confirmed,
          estimatedDelta: estimated,
          closingBalance: closing,
        ),
      );
      confirmedNet += confirmed;
      estimatedNet += estimated;
      balance = closing;
      if (closing < lowestBalance) {
        lowestBalance = closing;
        lowestDate = date;
      }
    }

    final estimatedMonthlyTotal = estimates.values.fold(
      0,
      (total, estimate) => total + estimate.monthlyAmount,
    );
    final limitations = _limitations(
      parameters: parameters,
      analysis: analysis,
      appliedEstimates: estimates,
      excludedCategoryNames: analysis.excludedNames(commitmentCategories),
      hasUncategorizedCommitment: hasUncategorizedCommitment,
    );
    final quality = ForecastDataQuality(
      historySufficient: analysis.sufficient,
      monthsWithExpenses: analysis.monthsWithExpenses,
      expenseMovements: analysis.expenseMovements,
      estimatedCategories: estimates.length,
      estimatedMonthlyTotal: estimatedMonthlyTotal,
      limitations: limitations,
    );

    return ForecastResult(
      cutoff: cutoff,
      endDate: endDate,
      openingBalance: request.openingBalance,
      days: days,
      commitments: commitmentLines,
      closingBalance: balance,
      lowestBalance: lowestBalance,
      lowestDate: lowestDate,
      confirmedNet: confirmedNet,
      estimatedNet: estimatedNet,
      quality: quality,
      assumptions: _assumptions(
        request: request,
        cutoff: cutoff,
        estimatesApplied: estimates.isNotEmpty,
      ),
      parameters: parameters,
    );
  }

  /// Estimativa diária pro-rata: a mediana mensal de cada categoria é
  /// repartida pelos dias do mês, com arredondamento acumulado para que a soma
  /// do mês seja exatamente a mediana (sem perder nem inventar FCFA).
  int _estimatedExpenseFor(
    DateTime date,
    Map<String, _CategoryEstimate> estimates,
  ) {
    final daysInMonth = DateTime(date.year, date.month + 1, 0).day;
    var total = 0;
    for (final estimate in estimates.values) {
      final current = estimate.monthlyAmount * date.day ~/ daysInMonth;
      final previous = estimate.monthlyAmount * (date.day - 1) ~/ daysInMonth;
      total += current - previous;
    }
    return -total;
  }

  List<String> _assumptions({
    required ForecastRequest request,
    required DateTime cutoff,
    required bool estimatesApplied,
  }) {
    final parameters = request.parameters;
    final cutoffText = FinancialDate.toDisplay(
      FinancialDate.fromDateTime(cutoff),
    );
    final opening = MoneyFormatter.formatXof(request.openingBalance);
    final assumptions = <String>[
      'Data de corte $cutoffText. Saldo de partida realizado: $opening.',
      'Compromissos abertos entram uma única vez na data de vencimento; os vencidos contam na data de corte.',
      'Compromissos pagos ou cancelados ficam de fora; pagamentos já realizados fazem parte do saldo de partida.',
      'Transferências entre contas próprias não alteram o saldo consolidado.',
    ];
    if (estimatesApplied) {
      assumptions
        ..add(
          'Despesas não planeadas: mediana mensal por categoria nos últimos '
          '${parameters.historyMonths} meses completos, repartida pelos dias '
          'de cada mês.',
        )
        ..add(
          'Categorias com compromissos conhecidos no horizonte não recebem '
          'estimativa histórica, para evitar dupla contagem.',
        )
        ..add(
          'As estimativas cobrem apenas despesas; rendimentos não planeados '
          'não são projetados.',
        );
    }
    return assumptions;
  }

  List<String> _limitations({
    required ForecastParameters parameters,
    required _HistoryAnalysis analysis,
    required Map<String, _CategoryEstimate> appliedEstimates,
    required List<String> excludedCategoryNames,
    required bool hasUncategorizedCommitment,
  }) {
    final limitations = <String>[
      'Previsão determinística a partir dos dados registados; não é garantia '
          'nem aconselhamento financeiro.',
    ];
    if (!parameters.useHistoricalEstimates) {
      limitations.add(
        'Estimativas históricas desativadas nos parâmetros: só compromissos '
        'conhecidos são projetados.',
      );
    } else if (!analysis.sufficient) {
      limitations.add(
        'Histórico insuficiente: são necessários '
        '${parameters.minMonthsWithExpenses} meses completos com despesas e '
        '${parameters.minExpenseMovements} despesas; existem '
        '${analysis.monthsWithExpenses} meses e '
        '${analysis.expenseMovements} despesas.',
      );
    } else if (appliedEstimates.isEmpty) {
      limitations.add(
        'As categorias com histórico têm compromissos conhecidos ou poucos '
        'meses de dados; não foram acrescentadas estimativas.',
      );
    }
    if (parameters.useHistoricalEstimates &&
        analysis.sufficient &&
        excludedCategoryNames.isNotEmpty) {
      limitations.add(
        'Excluídas das estimativas por já terem compromissos no horizonte: '
        '${excludedCategoryNames.join(', ')}.',
      );
    }
    if (hasUncategorizedCommitment && appliedEstimates.isNotEmpty) {
      limitations.add(
        'Compromissos sem categoria não são deduzidos das estimativas por '
        'categoria.',
      );
    }
    limitations.add(
      'Movimentos futuros que não sejam compromissos conhecidos não entram '
      'na projeção.',
    );
    return limitations;
  }
}

class _CategoryEstimate {
  const _CategoryEstimate({required this.monthlyAmount});

  final int monthlyAmount;
}

class _HistoryAnalysis {
  const _HistoryAnalysis({
    required this.sufficient,
    required this.monthsWithExpenses,
    required this.expenseMovements,
    required this._estimates,
    required this._names,
  });

  final bool sufficient;
  final int monthsWithExpenses;
  final int expenseMovements;
  final Map<String, _CategoryEstimate> _estimates;
  final Map<String, String> _names;

  static _HistoryAnalysis compute({
    required List<ForecastHistoryEntry> history,
    required DateTime cutoff,
    required ForecastParameters parameters,
  }) {
    final monthCount = parameters.historyMonths < 0
        ? 0
        : parameters.historyMonths;
    final startMonth = DateTime(cutoff.year, cutoff.month - monthCount);
    final endMonth = DateTime(cutoff.year, cutoff.month);
    final windowMonths = <int>[
      for (var index = 0; index < monthCount; index++)
        _monthKey(DateTime(startMonth.year, startMonth.month + index)),
    ];
    final entries = <ForecastHistoryEntry>[];
    for (final entry in history) {
      if (entry.amount <= 0) {
        continue;
      }
      final date = FinancialDate.dateOnly(entry.date);
      if (date.isBefore(startMonth) ||
          !date.isBefore(endMonth) ||
          date.isAfter(cutoff)) {
        continue;
      }
      entries.add(entry);
    }

    final monthsWithExpenses = <int>{};
    final totalsByCategory = <String, Map<int, int>>{};
    final names = <String, String>{};
    for (final entry in entries) {
      final month = _monthKey(entry.date);
      monthsWithExpenses.add(month);
      final key = entry.categoryId ?? '';
      names[key] = entry.categoryName ?? 'Sem categoria';
      final totals = totalsByCategory.putIfAbsent(key, () => <int, int>{});
      totals.update(
        month,
        (value) => value + entry.amount,
        ifAbsent: () => entry.amount,
      );
    }

    final sufficient =
        monthCount > 0 &&
        monthsWithExpenses.length >= parameters.minMonthsWithExpenses &&
        entries.length >= parameters.minExpenseMovements;

    final estimates = <String, _CategoryEstimate>{};
    if (sufficient) {
      for (final entry in totalsByCategory.entries) {
        final monthlyTotals = <int>[
          for (final month in windowMonths) entry.value[month] ?? 0,
        ];
        final presentMonths = monthlyTotals.where((value) => value > 0).length;
        if (presentMonths < parameters.minCategoryMonths) {
          continue;
        }
        final median = _median(monthlyTotals);
        if (median <= 0) {
          continue;
        }
        estimates[entry.key] = _CategoryEstimate(monthlyAmount: median);
      }
    }

    return _HistoryAnalysis(
      sufficient: sufficient,
      monthsWithExpenses: monthsWithExpenses.length,
      expenseMovements: entries.length,
      estimates: estimates,
      names: names,
    );
  }

  Map<String, _CategoryEstimate> estimatesExcluding(Set<String> categoryIds) {
    if (categoryIds.isEmpty) {
      return Map<String, _CategoryEstimate>.unmodifiable(_estimates);
    }
    return Map<String, _CategoryEstimate>.unmodifiable({
      for (final entry in _estimates.entries)
        if (!categoryIds.contains(entry.key)) entry.key: entry.value,
    });
  }

  List<String> excludedNames(Set<String> categoryIds) {
    final names = <String>[];
    for (final categoryId in categoryIds) {
      final name = _names[categoryId];
      if (name != null && _estimates.containsKey(categoryId)) {
        names.add(name);
      }
    }
    names.sort();
    return names;
  }

  static int _monthKey(DateTime date) => date.year * 12 + date.month;

  /// Mediana de valores inteiros; para uma quantidade par usa a média
  /// arredondada dos dois centrais. Os meses sem despesa contam como zero.
  static int _median(List<int> values) {
    final sorted = List<int>.of(values)..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) {
      return sorted[middle];
    }
    return (sorted[middle - 1] + sorted[middle] + 1) ~/ 2;
  }
}
