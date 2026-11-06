import 'package:financas_pessoais/features/planning/data/reminder_planner.dart';
import 'package:financas_pessoais/features/planning/domain/budget.dart';
import 'package:financas_pessoais/features/planning/domain/planned_item.dart';
import 'package:financas_pessoais/features/settings/domain/reminder_settings.dart';
import 'package:flutter_test/flutter_test.dart';

/// O formatador de moeda usa espaços não separáveis nos milhares.
String _norm(String value) =>
    value.replaceAll(RegExp(r'[\s\u00a0\u202f]'), ' ');

void main() {
  const planner = ReminderPlanner();
  const enabled = ReminderSettings(enabled: true, hour: 9, minute: 0);
  final now = DateTime(2026, 11, 1, 8);

  PlannedItem item({
    String id = 'item-1',
    PlannedItemKind kind = PlannedItemKind.expense,
    DateTime? dueDate,
    int amount = 60000,
    int paidTotal = 0,
    PlannedItemStatus status = PlannedItemStatus.planned,
    String? accountName = 'Carteira',
  }) {
    return PlannedItem(
      id: id,
      kind: kind,
      amount: amount,
      dueDate: dueDate ?? DateTime(2026, 11, 5),
      description: 'Renda',
      status: status,
      paidTotal: paidTotal,
      accountName: accountName,
    );
  }

  Budget budget({
    String id = 'budget-1',
    String categoryName = 'Alimentação',
    DateTime? periodStart,
    int limit = 10000,
    int spent = 12000,
  }) {
    return Budget(
      id: id,
      categoryId: 'category-$id',
      categoryName: categoryName,
      periodStart: periodStart ?? DateTime(2026, 11),
      limitAmount: limit,
      spent: spent,
    );
  }

  test('desativado não agenda nada', () {
    final result = planner.build(
      items: [item()],
      budgets: [budget()],
      settings: const ReminderSettings(enabled: false, hour: 9, minute: 0),
      now: now,
    );
    expect(result, isEmpty);
  });

  test('agenda a véspera e o dia do vencimento', () {
    final result = planner.build(
      items: [item()],
      budgets: const [],
      settings: enabled,
      now: now,
    );

    expect(result, hasLength(2));
    expect(result[0].when, DateTime(2026, 11, 4, 9));
    expect(result[0].title, 'Compromisso vence amanhã');
    expect(_norm(result[0].body), 'Pagar: Renda · 60 000 FCFA · Carteira');
    expect(result[1].when, DateTime(2026, 11, 5, 9));
    expect(result[1].title, 'Compromisso vence hoje');
    expect(result[0].id, isNot(result[1].id));
  });

  test('rendimento usa o verbo receber', () {
    final result = planner.build(
      items: [item(kind: PlannedItemKind.income)],
      budgets: const [],
      settings: enabled,
      now: now,
    );

    expect(result.last.title, 'Rendimento previsto hoje');
    expect(result.last.body, startsWith('Receber: Renda'));
  });

  test('não agenda horários já passados', () {
    final result = planner.build(
      items: [item(dueDate: DateTime(2026, 11, 1))],
      budgets: const [],
      settings: enabled,
      now: DateTime(2026, 11, 1, 10),
    );
    expect(result, isEmpty);
  });

  test('dia do vencimento ainda hoje é agendado se a hora não passou', () {
    final result = planner.build(
      items: [item(dueDate: DateTime(2026, 11, 1))],
      budgets: const [],
      settings: enabled,
      now: now,
    );
    expect(result, hasLength(1));
    expect(result.single.when, DateTime(2026, 11, 1, 9));
  });

  test('ignora compromissos pagos, cancelados ou vencidos', () {
    final result = planner.build(
      items: [
        item(id: 'pago', paidTotal: 60000),
        item(id: 'cancelado', status: PlannedItemStatus.cancelled),
        item(id: 'vencido', dueDate: DateTime(2026, 10, 30)),
      ],
      budgets: const [],
      settings: enabled,
      now: now,
    );
    expect(result, isEmpty);
  });

  test('ignora vencimentos além do horizonte', () {
    final result = planner.build(
      items: [item(dueDate: DateTime(2028, 11, 5))],
      budgets: const [],
      settings: enabled,
      now: now,
    );
    expect(result, isEmpty);
  });

  test('resume orçamentos excedidos no último dia do mês', () {
    final result = planner.build(
      items: const [],
      budgets: [
        budget(),
        budget(id: 'budget-2', categoryName: 'Transporte', spent: 15000),
        budget(id: 'budget-3', categoryName: 'Lazer', spent: 5000),
        budget(
          id: 'budget-outro-mes',
          categoryName: 'Saúde',
          periodStart: DateTime(2026, 12),
        ),
      ],
      settings: enabled,
      now: now,
    );

    expect(result, hasLength(1));
    final notification = result.single;
    expect(notification.when, DateTime(2026, 11, 30, 9));
    expect(notification.title, 'Orçamentos do mês');
    expect(
      notification.body,
      '2 orçamentos ultrapassaram o limite: Alimentação, Transporte.',
    );
    expect(notification.payload, '/planning/budgets');
  });

  test('um orçamento excedido usa uma frase no singular', () {
    final result = planner.build(
      items: const [],
      budgets: [budget()],
      settings: enabled,
      now: now,
    );
    expect(result.single.body, 'Alimentação ultrapassou o limite mensal.');
  });

  test('não agenda resumo depois do último dia do mês', () {
    final result = planner.build(
      items: const [],
      budgets: [budget()],
      settings: enabled,
      now: DateTime(2026, 11, 30, 10),
    );
    expect(result, isEmpty);
  });

  test('identificadores são estáveis entre cálculos', () {
    final first = planner.build(
      items: [item()],
      budgets: [budget()],
      settings: enabled,
      now: now,
    );
    final second = planner.build(
      items: [item()],
      budgets: [budget()],
      settings: enabled,
      now: now,
    );

    expect(
      first.map((notification) => notification.id),
      second.map((notification) => notification.id),
    );
    expect(
      first.map((notification) => notification.key).toSet(),
      hasLength(first.length),
    );
  });
}
