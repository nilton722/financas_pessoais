import 'account.dart';

/// Saldo de uma conta: saldo inicial + efeito líquido dos movimentos até à
/// data de referência. O cálculo vive no domínio; a soma dos movimentos vem
/// do repositório, já agregada em SQL.
class AccountBalance {
  const AccountBalance({required this.account, required this.movementDelta});

  final Account account;
  final int movementDelta;

  int get balance => account.openingBalance + movementDelta;
}

/// Saldo consolidado considera apenas contas ativas da mesma moeda.
/// Transferências entre contas próprias anulam-se: não são rendimento nem
/// despesa.
int consolidatedBalance(
  Iterable<AccountBalance> balances, {
  String currencyCode = 'XOF',
}) {
  return balances
      .where(
        (entry) =>
            !entry.account.isArchived &&
            entry.account.currencyCode == currencyCode,
      )
      .fold(0, (total, entry) => total + entry.balance);
}
