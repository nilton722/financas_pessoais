import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../../../core/formatters/date_formatter.dart';
import '../../../core/formatters/money_formatter.dart';
import '../data/budget_repository.dart';
import '../data/debt_repository.dart';
import '../data/planning_repository.dart';
import '../data/savings_goal_repository.dart';
import '../domain/budget.dart';
import '../domain/debt.dart';
import '../domain/planned_item.dart';
import '../domain/recurrence.dart';
import '../domain/savings_goal.dart';

final planningRepositoryProvider = Provider<PlanningRepository>(
  (ref) => PlanningRepository(ref.watch(appDatabaseProvider)),
);

final budgetRepositoryProvider = Provider<BudgetRepository>(
  (ref) => BudgetRepository(ref.watch(appDatabaseProvider)),
);

final savingsGoalRepositoryProvider = Provider<SavingsGoalRepository>(
  (ref) => SavingsGoalRepository(ref.watch(appDatabaseProvider)),
);

final debtRepositoryProvider = Provider<DebtRepository>(
  (ref) => DebtRepository(ref.watch(appDatabaseProvider)),
);

final plannedItemsProvider = StreamProvider<List<PlannedItem>>(
  (ref) => ref.watch(planningRepositoryProvider).watchItems(),
);

final pendingPlannedItemsProvider = StreamProvider<List<PlannedItem>>(
  (ref) => ref.watch(planningRepositoryProvider).watchItems(pendingOnly: true),
);

final plannedItemProvider = FutureProvider.family<PlannedItem?, String>(
  (ref, id) => ref.watch(planningRepositoryProvider).findItem(id),
);

final recurringRulesProvider = StreamProvider<List<RecurringRule>>(
  (ref) => ref.watch(planningRepositoryProvider).watchRules(),
);

final recurringRuleProvider = FutureProvider.family<RecurringRule?, String>(
  (ref, id) => ref.watch(planningRepositoryProvider).findRule(id),
);

class BudgetMonthController extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = FinancialDate.today();
    return DateTime(now.year, now.month);
  }

  void setMonth(DateTime month) {
    state = DateTime(month.year, month.month);
  }

  void previous() => state = DateTime(state.year, state.month - 1);

  void next() => state = DateTime(state.year, state.month + 1);
}

final budgetMonthProvider = NotifierProvider<BudgetMonthController, DateTime>(
  BudgetMonthController.new,
);

final budgetsProvider = StreamProvider<List<Budget>>((ref) {
  final month = ref.watch(budgetMonthProvider);
  return ref.watch(budgetRepositoryProvider).watchMonth(month);
});

class ShowArchivedGoals extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final showArchivedGoalsProvider = NotifierProvider<ShowArchivedGoals, bool>(
  ShowArchivedGoals.new,
);

final savingsGoalsProvider = StreamProvider<List<SavingsGoal>>((ref) {
  final includeArchived = ref.watch(showArchivedGoalsProvider);
  return ref
      .watch(savingsGoalRepositoryProvider)
      .watchAll(includeArchived: includeArchived);
});

final savingsGoalProvider = FutureProvider.family<SavingsGoal?, String>(
  (ref, id) => ref.watch(savingsGoalRepositoryProvider).findById(id),
);

final debtsProvider = StreamProvider<List<Debt>>(
  (ref) => ref.watch(debtRepositoryProvider).watchDebts(),
);

final debtProvider = FutureProvider.family<Debt?, String>(
  (ref, id) => ref.watch(debtRepositoryProvider).findById(id),
);

/// Alerta local, mostrado apenas dentro da app (sem notificações do sistema).
class PlanningAlert {
  const PlanningAlert({
    required this.icon,
    required this.title,
    required this.message,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String message;
  final String route;
}

/// Resumo de alertas de vencimento e orçamento. É derivado dos mesmos
/// streams que alimentam as listas, pelo que desaparece assim que o
/// compromisso é pago, cancelado ou o orçamento é ajustado.
final planningAlertsProvider = Provider<List<PlanningAlert>>((ref) {
  final today = FinancialDate.today();
  final items =
      ref.watch(pendingPlannedItemsProvider).value ?? const <PlannedItem>[];
  final debts = ref.watch(debtsProvider).value ?? const <Debt>[];
  final budgets = ref.watch(budgetsProvider).value ?? const <Budget>[];

  final alerts = <PlanningAlert>[];
  for (final item in items) {
    if (item.isOverdue(today)) {
      alerts.add(
        PlanningAlert(
          icon: Icons.warning_amber_outlined,
          title: 'Compromisso vencido',
          message:
              '${item.description} · ${MoneyFormatter.formatXof(item.remaining)}',
          route: '/planning/commitments',
        ),
      );
    } else if (item.isDueWithin(today, days: 7)) {
      alerts.add(
        PlanningAlert(
          icon: Icons.schedule_outlined,
          title: 'Vence nos próximos 7 dias',
          message:
              '${item.description} · ${MoneyFormatter.formatXof(item.remaining)}',
          route: '/planning/commitments',
        ),
      );
    }
  }
  for (final debt in debts.where((debt) => debt.isOverdue(today))) {
    alerts.add(
      PlanningAlert(
        icon: Icons.gavel_outlined,
        title: debt.kind == DebtKind.payable
            ? 'Dívida vencida a pagar'
            : 'Dívida vencida a receber',
        message:
            '${debt.description} · ${MoneyFormatter.formatXof(debt.remaining)}',
        route: '/planning/debts',
      ),
    );
  }
  for (final budget in budgets.where((budget) => budget.isExceeded)) {
    alerts.add(
      PlanningAlert(
        icon: Icons.speed_outlined,
        title: 'Orçamento excedido',
        message:
            '${budget.categoryName}: '
            '${MoneyFormatter.formatXof(budget.spent)} de '
            '${MoneyFormatter.formatXof(budget.limitAmount)}',
        route: '/planning/budgets',
      ),
    );
  }
  return alerts;
});
