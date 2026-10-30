import 'package:financas_pessoais/features/accounts/domain/account.dart';
import 'package:financas_pessoais/features/accounts/domain/account_balance.dart';
import 'package:flutter_test/flutter_test.dart';

Account _account({
  String id = 'account-1',
  int openingBalance = 0,
  bool isArchived = false,
  String currencyCode = 'XOF',
}) {
  return Account(
    id: id,
    name: 'Conta $id',
    type: AccountType.cash,
    currencyCode: currencyCode,
    openingBalance: openingBalance,
    openingDate: DateTime(2026),
    isArchived: isArchived,
  );
}

void main() {
  group('AccountBalance', () {
    test('soma o saldo inicial ao efeito dos movimentos', () {
      final entry = AccountBalance(
        account: _account(openingBalance: 5000),
        movementDelta: -1200,
      );
      expect(entry.balance, 3800);
    });
  });

  group('consolidatedBalance', () {
    test('soma contas ativas da mesma moeda', () {
      final total = consolidatedBalance([
        AccountBalance(
          account: _account(openingBalance: 5000),
          movementDelta: 0,
        ),
        AccountBalance(
          account: _account(id: 'account-2', openingBalance: 2000),
          movementDelta: -500,
        ),
      ]);
      expect(total, 6500);
    });

    test('ignora contas arquivadas', () {
      final total = consolidatedBalance([
        AccountBalance(
          account: _account(openingBalance: 5000),
          movementDelta: 0,
        ),
        AccountBalance(
          account: _account(
            id: 'account-2',
            openingBalance: 9000,
            isArchived: true,
          ),
          movementDelta: 0,
        ),
      ]);
      expect(total, 5000);
    });

    test('ignora contas noutra moeda', () {
      final total = consolidatedBalance([
        AccountBalance(
          account: _account(openingBalance: 5000),
          movementDelta: 0,
        ),
        AccountBalance(
          account: _account(
            id: 'account-2',
            openingBalance: 100,
            currencyCode: 'EUR',
          ),
          movementDelta: 0,
        ),
      ]);
      expect(total, 5000);
    });

    test('lista vazia resulta em zero', () {
      expect(consolidatedBalance(const []), 0);
    });
  });

  group('AccountDraft.validate', () {
    AccountDraft draft({
      String name = 'Carteira',
      int openingBalance = 0,
      DateTime? openingDate,
    }) {
      return AccountDraft(
        name: name,
        type: AccountType.cash,
        openingBalance: openingBalance,
        openingDate: openingDate ?? DateTime.now(),
      );
    }

    test('aceita dados válidos', () {
      expect(draft().validate(), isEmpty);
    });

    test('rejeita nome vazio', () {
      expect(draft(name: '   ').validate()['name'], isNotNull);
    });

    test('rejeita nome demasiado longo', () {
      expect(draft(name: 'a' * 61).validate()['name'], isNotNull);
    });

    test('rejeita montante acima do máximo', () {
      expect(
        draft(openingBalance: 1000000000000).validate()['openingBalance'],
        isNotNull,
      );
    });

    test('rejeita data de abertura futura', () {
      final future = DateTime.now().add(const Duration(days: 2));
      expect(draft(openingDate: future).validate()['openingDate'], isNotNull);
    });
  });
}
