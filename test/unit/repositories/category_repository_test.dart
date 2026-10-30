import 'package:financas_pessoais/core/database/app_database.dart';
import 'package:financas_pessoais/core/errors/app_failure.dart';
import 'package:financas_pessoais/core/formatters/date_formatter.dart';
import 'package:financas_pessoais/features/categories/data/category_repository.dart';
import 'package:financas_pessoais/features/categories/domain/category.dart';
import 'package:financas_pessoais/features/transactions/data/transaction_repository.dart';
import 'package:financas_pessoais/features/transactions/domain/movement.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/database_fixtures.dart';
import '../../support/domain_fixtures.dart';

void main() {
  late AppDatabase db;
  late CategoryRepository categories;
  late TransactionRepository transactions;

  setUp(() {
    db = openMemoryDatabase();
    categories = CategoryRepository(db);
    transactions = TransactionRepository(db);
  });

  tearDown(() => db.close());

  test(
    'rejeita nome duplicado no mesmo tipo e permite no tipo oposto',
    () async {
      await expectLater(
        categories.create(
          const CategoryDraft(name: 'Alimentação', kind: CategoryKind.expense),
        ),
        throwsA(isA<AppFailure>()),
      );

      final incomeId = await categories.create(
        const CategoryDraft(name: 'Alimentação', kind: CategoryKind.income),
      );
      final income = await categories.findById(incomeId);
      expect(income?.kind, CategoryKind.income);
      expect(income?.isSystem, isFalse);
    },
  );

  test('edição impede duplicar nome ativo', () async {
    final id = await categories.create(
      const CategoryDraft(name: 'Poupança', kind: CategoryKind.expense),
    );

    await expectLater(
      categories.update(
        id,
        const CategoryDraft(name: 'Transporte', kind: CategoryKind.expense),
      ),
      throwsA(isA<AppFailure>()),
    );

    await categories.update(
      id,
      const CategoryDraft(name: 'Poupança casa', kind: CategoryKind.expense),
    );
    expect((await categories.findById(id))?.name, 'Poupança casa');
  });

  test('arquivar mantém a categoria referenciada por movimentos', () async {
    final categoryId = await categories.create(
      const CategoryDraft(name: 'Extra', kind: CategoryKind.expense),
    );
    final accountId = await createTestAccount(db);
    await transactions.createMovement(
      MovementDraft(
        kind: MovementKind.expense,
        amount: 900,
        date: FinancialDate.today(),
        accountId: accountId,
        categoryId: categoryId,
        description: 'Teste',
      ),
    );

    await categories.setArchived(categoryId, archived: true);

    final active = await categories.watchAll().first;
    expect(active.map((category) => category.id), isNot(contains(categoryId)));
    final all = await categories.watchAll(includeArchived: true).first;
    expect(all.map((category) => category.id), contains(categoryId));

    final items = await transactions
        .watchMovements(const MovementFilter())
        .first;
    expect(items.single.categoryName, 'Extra');

    await expectLater(
      transactions.createMovement(
        MovementDraft(
          kind: MovementKind.expense,
          amount: 100,
          date: FinancialDate.today(),
          accountId: accountId,
          categoryId: categoryId,
          description: 'Depois de arquivada',
        ),
      ),
      throwsA(isA<AppFailure>()),
    );
  });

  test('filtra categorias por tipo', () async {
    final income = await categories.watchAll(kind: CategoryKind.income).first;
    final expense = await categories.watchAll(kind: CategoryKind.expense).first;

    expect(income.map((category) => category.kind).toSet(), {
      CategoryKind.income,
    });
    expect(expense.length, greaterThan(income.length));
    expect(
      (await categories.watchAll().first).length,
      income.length + expense.length,
    );
  });
}
