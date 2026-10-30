import '../../../core/formatters/date_formatter.dart';
import '../../../core/formatters/money_input_parser.dart';

enum AccountType {
  cash('cash', 'Dinheiro'),
  bank('bank', 'Banco'),
  mobileWallet('mobile_wallet', 'Carteira móvel'),
  savings('savings', 'Poupança'),
  other('other', 'Outro');

  const AccountType(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static AccountType fromDb(String value) => values.firstWhere(
    (type) => type.dbValue == value,
    orElse: () => AccountType.other,
  );
}

class Account {
  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.currencyCode,
    required this.openingBalance,
    required this.openingDate,
    required this.isArchived,
  });

  final String id;
  final String name;
  final AccountType type;
  final String currencyCode;
  final int openingBalance;
  final DateTime openingDate;
  final bool isArchived;
}

class AccountDraft {
  const AccountDraft({
    required this.name,
    required this.type,
    required this.openingBalance,
    required this.openingDate,
    this.currencyCode = 'XOF',
  });

  final String name;
  final AccountType type;
  final int openingBalance;
  final DateTime openingDate;
  final String currencyCode;

  Map<String, String> validate() {
    final errors = <String, String>{};
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      errors['name'] = 'Indique o nome da conta.';
    } else if (trimmedName.length > 60) {
      errors['name'] = 'O nome não pode exceder 60 caracteres.';
    }
    if (openingBalance.abs() > MoneyInputParser.maxAmount) {
      errors['openingBalance'] = 'Montante demasiado elevado.';
    }
    if (FinancialDate.dateOnly(openingDate).isAfter(FinancialDate.today())) {
      errors['openingDate'] = 'A data de abertura não pode ser futura.';
    }
    return errors;
  }
}
