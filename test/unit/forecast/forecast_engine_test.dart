import 'package:financas_pessoais/features/forecast/domain/forecast.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = ForecastEngine();
  final cutoff = DateTime(2026, 10, 30);

  ForecastRequest request({
    int opening = 100000,
    DateTime? cutoffDate,
    List<ForecastCommitment> commitments = const [],
    List<ForecastHistoryEntry> history = const [],
    ForecastParameters parameters = const ForecastParameters(),
  }) => ForecastRequest(
    cutoff: cutoffDate ?? cutoff,
    openingBalance: opening,
    commitments: commitments,
    history: history,
    parameters: parameters,
  );

  ForecastCommitment expense(
    String description,
    int amount,
    DateTime dueDate, {
    String? categoryId,
    String? categoryName,
  }) => ForecastCommitment(
    id: description,
    flow: ForecastFlow.outflow,
    amount: amount,
    dueDate: dueDate,
    description: description,
    categoryId: categoryId,
    categoryName: categoryName,
  );

  ForecastCommitment income(String description, int amount, DateTime dueDate) =>
      ForecastCommitment(
        id: description,
        flow: ForecastFlow.inflow,
        amount: amount,
        dueDate: dueDate,
        description: description,
      );

  List<ForecastHistoryEntry> threeCompleteMonths() => [
    ForecastHistoryEntry(
      date: DateTime(2026, 7, 10),
      amount: 3000,
      categoryId: 'food',
      categoryName: 'Alimentação',
    ),
    ForecastHistoryEntry(
      date: DateTime(2026, 7, 12),
      amount: 1000,
      categoryId: 'transport',
      categoryName: 'Transporte',
    ),
    ForecastHistoryEntry(
      date: DateTime(2026, 8, 10),
      amount: 3000,
      categoryId: 'food',
      categoryName: 'Alimentação',
    ),
    ForecastHistoryEntry(
      date: DateTime(2026, 8, 12),
      amount: 1000,
      categoryId: 'transport',
      categoryName: 'Transporte',
    ),
    ForecastHistoryEntry(
      date: DateTime(2026, 9, 10),
      amount: 6000,
      categoryId: 'food',
      categoryName: 'Alimentação',
    ),
    ForecastHistoryEntry(
      date: DateTime(2026, 9, 12),
      amount: 1000,
      categoryId: 'transport',
      categoryName: 'Transporte',
    ),
    ForecastHistoryEntry(
      date: DateTime(2026, 9, 20),
      amount: 5000,
      categoryId: 'health',
      categoryName: 'Saúde',
    ),
  ];

  test('sem histórico projeta apenas compromissos conhecidos', () {
    final result = engine.run(
      request(
        commitments: [
          expense('Renda', 30000, DateTime(2026, 11, 1)),
          income('Reembolso', 10000, DateTime(2026, 11, 4)),
        ],
        parameters: const ForecastParameters(horizonDays: 7),
      ),
    );

    expect(result.openingBalance, 100000);
    expect(result.days, hasLength(8));
    expect(result.days.first.closingBalance, 100000);
    expect(result.days[2].confirmedDelta, -30000);
    expect(result.days[5].confirmedDelta, 10000);
    expect(result.confirmedNet, -20000);
    expect(result.estimatedNet, 0);
    expect(result.closingBalance, 80000);
    expect(result.lowestBalance, 70000);
    expect(result.lowestDate, DateTime(2026, 11, 1));
    expect(result.commitments, hasLength(2));
    expect(result.quality.historySufficient, isFalse);
    expect(result.quality.estimatedCategories, 0);
    expect(
      result.quality.limitations.any(
        (text) => text.contains('Histórico insuficiente'),
      ),
      isTrue,
    );
    expect(
      result.assumptions.any(
        (text) => text.contains('Saldo de partida realizado'),
      ),
      isTrue,
    );
  });

  test('vencidos contam na data de corte e além do horizonte ficam fora', () {
    final result = engine.run(
      request(
        opening: 50000,
        commitments: [
          expense('Conta atrasada', 20000, DateTime(2026, 10, 20)),
          expense('Fora do horizonte', 10000, DateTime(2026, 11, 10)),
        ],
        parameters: const ForecastParameters(horizonDays: 7),
      ),
    );

    expect(result.days.first.confirmedDelta, -20000);
    expect(result.days.first.closingBalance, 30000);
    expect(result.commitments, hasLength(1));
    expect(result.commitments.single.description, 'Conta atrasada');
    expect(result.closingBalance, 30000);
  });

  test('histórico insuficiente não gera estimativas', () {
    final result = engine.run(
      request(
        cutoffDate: DateTime(2026, 10, 31),
        history: [
          ForecastHistoryEntry(
            date: DateTime(2026, 8, 10),
            amount: 3000,
            categoryId: 'food',
            categoryName: 'Alimentação',
          ),
          ForecastHistoryEntry(
            date: DateTime(2026, 9, 10),
            amount: 6000,
            categoryId: 'food',
            categoryName: 'Alimentação',
          ),
        ],
        parameters: const ForecastParameters(horizonDays: 30),
      ),
    );

    expect(result.quality.historySufficient, isFalse);
    expect(result.quality.monthsWithExpenses, 2);
    expect(result.quality.expenseMovements, 2);
    expect(result.estimatedNet, 0);
    expect(result.closingBalance, 100000);
    expect(
      result.quality.limitations.any(
        (text) => text.contains('são necessários 3 meses'),
      ),
      isTrue,
    );
  });

  test('histórico suficiente usa mediana mensal por categoria', () {
    final result = engine.run(
      request(
        cutoffDate: DateTime(2026, 10, 31),
        history: threeCompleteMonths(),
        parameters: const ForecastParameters(horizonDays: 30),
      ),
    );

    expect(result.quality.historySufficient, isTrue);
    expect(result.quality.monthsWithExpenses, 3);
    expect(result.quality.expenseMovements, 7);
    expect(result.quality.estimatedCategories, 2);
    expect(result.quality.estimatedMonthlyTotal, 4000);
    expect(result.estimatedNet, -4000);
    expect(result.closingBalance, 96000);
    expect(result.days, hasLength(31));
    expect(result.days.first.date, DateTime(2026, 10, 31));
    expect(result.days.last.date, DateTime(2026, 11, 30));
    expect(result.days.skip(1).every((day) => day.estimatedDelta <= 0), isTrue);
    expect(
      result.days.skip(1).fold(0, (total, day) => total + day.estimatedDelta),
      -4000,
    );
    expect(
      result.assumptions.any((text) => text.contains('mediana mensal')),
      isTrue,
    );
  });

  test('categoria com compromisso não recebe estimativa histórica', () {
    final result = engine.run(
      request(
        cutoffDate: DateTime(2026, 10, 31),
        history: threeCompleteMonths(),
        commitments: [
          expense(
            'Mercado',
            2000,
            DateTime(2026, 11, 10),
            categoryId: 'food',
            categoryName: 'Alimentação',
          ),
        ],
        parameters: const ForecastParameters(horizonDays: 30),
      ),
    );

    expect(result.confirmedNet, -2000);
    expect(result.estimatedNet, -1000);
    expect(result.closingBalance, 97000);
    expect(result.quality.estimatedCategories, 1);
    expect(result.quality.estimatedMonthlyTotal, 1000);
    expect(
      result.quality.limitations.any((text) => text.contains('Alimentação')),
      isTrue,
    );
    expect(
      result.assumptions.any((text) => text.contains('não recebem')),
      isTrue,
    );
  });

  test('estimativas desativadas nos parâmetros não alteram o saldo', () {
    final result = engine.run(
      request(
        cutoffDate: DateTime(2026, 10, 31),
        history: threeCompleteMonths(),
        parameters: const ForecastParameters(
          horizonDays: 30,
          useHistoricalEstimates: false,
        ),
      ),
    );

    expect(result.quality.historySufficient, isTrue);
    expect(result.quality.estimatedCategories, 0);
    expect(result.estimatedNet, 0);
    expect(result.closingBalance, 100000);
    expect(
      result.quality.limitations.any((text) => text.contains('desativadas')),
      isTrue,
    );
  });

  test('fim de ano projeta corretamente janeiro do ano seguinte', () {
    final history = [
      for (final month in [9, 10, 11]) ...[
        ForecastHistoryEntry(
          date: DateTime(2026, month, 10),
          amount: 3000,
          categoryId: 'food',
          categoryName: 'Alimentação',
        ),
        ForecastHistoryEntry(
          date: DateTime(2026, month, 12),
          amount: 1000,
          categoryId: 'transport',
          categoryName: 'Transporte',
        ),
      ],
    ];
    final result = engine.run(
      request(
        cutoffDate: DateTime(2026, 12, 31),
        history: history,
        parameters: const ForecastParameters(horizonDays: 31),
      ),
    );

    expect(result.quality.historySufficient, isTrue);
    expect(result.endDate, DateTime(2027, 1, 31));
    expect(result.days, hasLength(32));
    expect(result.days.last.date, DateTime(2027, 1, 31));
    expect(result.estimatedNet, -4000);
    expect(result.closingBalance, 96000);
  });

  test('sinaliza possível saldo negativo com data', () {
    final result = engine.run(
      request(
        opening: 1000,
        commitments: [expense('Compra', 2000, DateTime(2026, 11, 1))],
        parameters: const ForecastParameters(horizonDays: 7),
      ),
    );

    expect(result.hasNegativeBalance, isTrue);
    expect(result.lowestBalance, -1000);
    expect(result.lowestDate, DateTime(2026, 11, 1));
    expect(result.firstNegativeDate, DateTime(2026, 11, 1));
    expect(result.days[2].isNegative, isTrue);
  });

  test('os mesmos dados produzem o mesmo resultado', () {
    final input = request(
      cutoffDate: DateTime(2026, 10, 31),
      history: threeCompleteMonths(),
      commitments: [
        expense('Renda', 20000, DateTime(2026, 11, 5)),
        income('Salário', 50000, DateTime(2026, 11, 20)),
      ],
      parameters: const ForecastParameters(horizonDays: 30),
    );

    final first = engine.run(input);
    final second = engine.run(input);

    expect(first.closingBalance, second.closingBalance);
    expect(first.lowestBalance, second.lowestBalance);
    expect(first.lowestDate, second.lowestDate);
    expect(first.confirmedNet, second.confirmedNet);
    expect(first.estimatedNet, second.estimatedNet);
    expect(first.quality.summary, second.quality.summary);
    expect(first.quality.limitations, second.quality.limitations);
    expect(first.assumptions, second.assumptions);
    expect(
      first.days
          .map(
            (day) => [
              day.date,
              day.openingBalance,
              day.confirmedDelta,
              day.estimatedDelta,
              day.closingBalance,
            ],
          )
          .toList(),
      second.days
          .map(
            (day) => [
              day.date,
              day.openingBalance,
              day.confirmedDelta,
              day.estimatedDelta,
              day.closingBalance,
            ],
          )
          .toList(),
    );
  });
}
