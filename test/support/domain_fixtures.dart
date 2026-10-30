import 'package:financas_pessoais/core/database/app_database.dart';
import 'package:financas_pessoais/core/formatters/date_formatter.dart';
import 'package:financas_pessoais/features/accounts/data/account_repository.dart';
import 'package:financas_pessoais/features/accounts/domain/account.dart';
import 'package:financas_pessoais/features/categories/data/category_repository.dart';
import 'package:financas_pessoais/features/categories/domain/category.dart';

/// IDs semeados em `default_seeds.dart`, reutilizados pelos testes de
/// movimentos para não depender de nomes traduzidos.
const String seededSalaryCategoryId = '00000000-0000-4000-8000-000000000101';
const String seededFoodCategoryId = '00000000-0000-4000-8000-000000000201';

Future<String> createTestAccount(
  AppDatabase database, {
  String name = 'Carteira',
  AccountType type = AccountType.cash,
  int openingBalance = 0,
  DateTime? openingDate,
}) {
  return AccountRepository(database).create(
    AccountDraft(
      name: name,
      type: type,
      openingBalance: openingBalance,
      openingDate: openingDate ?? FinancialDate.today(),
    ),
  );
}

Future<String> createTestCategory(
  AppDatabase database, {
  required String name,
  required CategoryKind kind,
}) {
  return CategoryRepository(database)
      .create(CategoryDraft(name: name, kind: kind));
}

DateTime daysAgo(int days) =>
    FinancialDate.today().subtract(Duration(days: days));
