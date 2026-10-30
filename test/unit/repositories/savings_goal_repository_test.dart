import 'package:financas_pessoais/core/database/app_database.dart'
    hide SavingsGoal;
import 'package:financas_pessoais/core/formatters/date_formatter.dart';
import 'package:financas_pessoais/features/accounts/data/account_repository.dart';
import 'package:financas_pessoais/features/planning/data/savings_goal_repository.dart';
import 'package:financas_pessoais/features/planning/domain/savings_goal.dart';
import 'package:financas_pessoais/features/transactions/data/transaction_repository.dart';
import 'package:financas_pessoais/features/transactions/domain/movement.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/database_fixtures.dart';
import '../../support/domain_fixtures.dart';

void main() {
  late AppDatabase db;
  late TransactionRepository transactions;
  late SavingsGoalRepository goals;

  setUp(() {
    db = openMemoryDatabase();
    transactions = TransactionRepository(db);
    goals = SavingsGoalRepository(db);
  });

  tearDown(() => db.close());

  SavingsGoalDraft draft({
    String name = 'Viagem',
    int target = 100000,
    String? accountId,
  }) {
    return SavingsGoalDraft(
      name: name,
      targetAmount: target,
      targetDate: FinancialDate.today().add(const Duration(days: 180)),
      linkedAccountId: accountId,
      notes: 'Poupança mensal',
    );
  }

  test('progresso deriva do saldo real da conta associada', () async {
    final wallet = await createTestAccount(db, name: 'Carteira');
    final savings = await createTestAccount(db, name: 'Poupança');
    final goalId = await goals.create(draft(accountId: savings));

    var goal = await goals.findById(goalId);
    expect(goal!.currentAmount, 0);
    expect(goal.progress, 0);

    await transactions.createMovement(
      MovementDraft(
        kind: MovementKind.income,
        amount: 25000,
        date: FinancialDate.today(),
        accountId: savings,
        categoryId: seededSalaryCategoryId,
        description: 'Reforço da meta',
      ),
    );

    goal = await goals.findById(goalId);
    expect(goal!.currentAmount, 25000);
    expect(goal.remaining, 75000);
    expect(goal.progress, closeTo(0.25, 0.0001));

    // A meta em si não é despesa: o saldo da carteira ficou intacto.
    final balances = await AccountRepositoryHelper.balances(db);
    expect(balances[wallet], 0);
    expect(balances[savings], 25000);
  });

  test('transferência para a conta da meta aumenta o progresso', () async {
    final wallet = await createTestAccount(
      db,
      name: 'Carteira',
      openingBalance: 40000,
    );
    final savings = await createTestAccount(db, name: 'Poupança');
    final goalId = await goals.create(draft(accountId: savings));

    await transactions.createTransfer(
      TransferDraft(
        sourceAccountId: wallet,
        destinationAccountId: savings,
        amount: 15000,
        date: FinancialDate.today(),
        description: 'Reserva',
      ),
    );

    final goal = await goals.findById(goalId);
    expect(goal!.currentAmount, 15000);
    final balances = await AccountRepositoryHelper.balances(db);
    expect(balances[wallet], 25000);
    expect(balances[savings], 15000);
  });

  test('meta sem conta associada tem progresso zero', () async {
    final goalId = await goals.create(draft());
    final goal = await goals.findById(goalId);
    expect(goal!.currentAmount, 0);
    expect(goal.linkedAccountId, isNull);
  });

  test('arquivar esconde a meta e pode ser revertido', () async {
    final goalId = await goals.create(draft());
    await goals.setArchived(goalId, archived: true);

    expect(await goals.readAll(), isEmpty);
    expect(await goals.readAll(includeArchived: true), hasLength(1));

    await goals.setArchived(goalId, archived: false);
    expect(await goals.readAll(), hasLength(1));
  });

  test('meta atingida e vencida', () {
    final goal = SavingsGoal(
      id: 'g',
      name: 'Fundo',
      targetAmount: 1000,
      currentAmount: 1000,
      isArchived: false,
      targetDate: DateTime(2020, 1, 1),
    );
    expect(goal.isReached, isTrue);
    expect(goal.remaining, 0);
    expect(goal.progress, 1);
    expect(goal.isOverdue(DateTime(2026, 10, 30)), isFalse);
  });
}

abstract final class AccountRepositoryHelper {
  static Future<Map<String, int>> balances(AppDatabase db) async {
    final entries = await AccountRepository(db)
        .readBalances(until: FinancialDate.today(), includeArchived: true);
    return {for (final entry in entries) entry.account.id: entry.balance};
  }
}
