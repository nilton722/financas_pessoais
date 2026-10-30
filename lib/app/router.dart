import 'package:go_router/go_router.dart';

import '../features/accounts/presentation/account_form_page.dart';
import '../features/accounts/presentation/accounts_page.dart';
import '../features/categories/presentation/categories_page.dart';
import '../features/categories/presentation/category_form_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/planning/presentation/budget_form_page.dart';
import '../features/planning/presentation/budgets_page.dart';
import '../features/planning/presentation/commitment_form_page.dart';
import '../features/planning/presentation/commitments_page.dart';
import '../features/planning/presentation/debt_form_page.dart';
import '../features/planning/presentation/debts_page.dart';
import '../features/planning/presentation/pay_commitment_page.dart';
import '../features/planning/presentation/pay_debt_page.dart';
import '../features/planning/presentation/planning_hub_page.dart';
import '../features/planning/presentation/recurrence_form_page.dart';
import '../features/planning/presentation/recurrences_page.dart';
import '../features/planning/presentation/savings_goal_form_page.dart';
import '../features/planning/presentation/savings_goals_page.dart';
import '../features/transactions/presentation/movement_form_page.dart';
import '../features/transactions/presentation/movements_page.dart';
import 'shell/app_shell.dart';

GoRouter buildRouter() => GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/', builder: (context, state) => const DashboardPage()),
        GoRoute(
          path: '/movements',
          builder: (context, state) => const MovementsPage(),
          routes: [
            GoRoute(
              path: 'new',
              builder: (context, state) => const MovementFormPage(),
            ),
            GoRoute(
              path: ':id/edit',
              builder: (context, state) =>
                  MovementFormPage(movementId: state.pathParameters['id']),
            ),
          ],
        ),
        GoRoute(
          path: '/accounts',
          builder: (context, state) => const AccountsPage(),
          routes: [
            GoRoute(
              path: 'new',
              builder: (context, state) => const AccountFormPage(),
            ),
            GoRoute(
              path: ':id/edit',
              builder: (context, state) =>
                  AccountFormPage(accountId: state.pathParameters['id']),
            ),
          ],
        ),
        GoRoute(
          path: '/categories',
          builder: (context, state) => const CategoriesPage(),
          routes: [
            GoRoute(
              path: 'new',
              builder: (context, state) => const CategoryFormPage(),
            ),
            GoRoute(
              path: ':id/edit',
              builder: (context, state) =>
                  CategoryFormPage(categoryId: state.pathParameters['id']),
            ),
          ],
        ),
        GoRoute(
          path: '/planning',
          builder: (context, state) => const PlanningHubPage(),
          routes: [
            GoRoute(
              path: 'commitments',
              builder: (context, state) => const CommitmentsPage(),
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (context, state) => const CommitmentFormPage(),
                ),
                GoRoute(
                  path: ':id/edit',
                  builder: (context, state) =>
                      CommitmentFormPage(itemId: state.pathParameters['id']),
                ),
                GoRoute(
                  path: ':id/pay',
                  builder: (context, state) =>
                      PayCommitmentPage(itemId: state.pathParameters['id']!),
                ),
              ],
            ),
            GoRoute(
              path: 'budgets',
              builder: (context, state) => const BudgetsPage(),
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (context, state) => const BudgetFormPage(),
                ),
              ],
            ),
            GoRoute(
              path: 'recurrences',
              builder: (context, state) => const RecurrencesPage(),
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (context, state) => const RecurrenceFormPage(),
                ),
                GoRoute(
                  path: ':id/edit',
                  builder: (context, state) =>
                      RecurrenceFormPage(ruleId: state.pathParameters['id']),
                ),
              ],
            ),
            GoRoute(
              path: 'goals',
              builder: (context, state) => const SavingsGoalsPage(),
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (context, state) => const SavingsGoalFormPage(),
                ),
                GoRoute(
                  path: ':id/edit',
                  builder: (context, state) =>
                      SavingsGoalFormPage(goalId: state.pathParameters['id']),
                ),
              ],
            ),
            GoRoute(
              path: 'debts',
              builder: (context, state) => const DebtsPage(),
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (context, state) => const DebtFormPage(),
                ),
                GoRoute(
                  path: ':id/edit',
                  builder: (context, state) =>
                      DebtFormPage(debtId: state.pathParameters['id']),
                ),
                GoRoute(
                  path: ':id/pay',
                  builder: (context, state) =>
                      PayDebtPage(debtId: state.pathParameters['id']!),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);
