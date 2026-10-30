import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart' as db;
import '../../../core/errors/app_failure.dart';
import '../../../core/formatters/date_formatter.dart';
import '../../../core/utils/id.dart';
import '../../../core/utils/time.dart';
import '../domain/account.dart';
import '../domain/account_balance.dart';

class AccountRepository {
  AccountRepository(this._db);

  final db.AppDatabase _db;

  Stream<List<Account>> watchAll({bool includeArchived = false}) {
    final query = _db.select(_db.accounts)
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
    if (!includeArchived) {
      query.where((t) => t.isArchived.equals(false));
    }
    return query.watch().map(
      (rows) => rows.map(_toDomain).toList(growable: false),
    );
  }

  /// Saldo por conta até `until`: saldo inicial mais o efeito líquido de
  /// rendimentos, despesas e transferências (crédito no destino, débito na
  /// origem). Movimentos eliminados logicamente ficam de fora.
  Stream<List<AccountBalance>> watchBalances({
    required DateTime until,
    bool includeArchived = false,
  }) {
    return _balancesQuery(
      until: until,
      includeArchived: includeArchived,
    ).watch().map(_toBalances);
  }

  /// Leitura pontual dos saldos, sem subscrição contínua.
  Future<List<AccountBalance>> readBalances({
    required DateTime until,
    bool includeArchived = false,
  }) async {
    final rows = await _balancesQuery(
      until: until,
      includeArchived: includeArchived,
    ).get();
    return _toBalances(rows);
  }

  Selectable<QueryRow> _balancesQuery({
    required DateTime until,
    required bool includeArchived,
  }) {
    final untilDate = FinancialDate.fromDateTime(until);
    const sql = '''
SELECT a.id, a.name, a.type, a.currency_code, a.opening_balance,
       a.opening_date, a.is_archived,
       COALESCE(SUM(m.delta), 0) AS movement_delta
FROM accounts a
LEFT JOIN (
  SELECT account_id,
         CASE WHEN kind = 'income' THEN amount ELSE -amount END AS delta
    FROM transactions
   WHERE deleted_at IS NULL
     AND kind IN ('income', 'expense')
     AND transaction_date <= ?
  UNION ALL
  SELECT account_id, -amount AS delta
    FROM transactions
   WHERE deleted_at IS NULL AND kind = 'transfer' AND transaction_date <= ?
  UNION ALL
  SELECT destination_account_id AS account_id, amount AS delta
    FROM transactions
   WHERE deleted_at IS NULL AND kind = 'transfer' AND transaction_date <= ?
) m ON m.account_id = a.id
WHERE ? = 1 OR a.is_archived = 0
GROUP BY a.id
ORDER BY a.name COLLATE NOCASE
''';
    final variables = [
      Variable.withString(untilDate),
      Variable.withString(untilDate),
      Variable.withString(untilDate),
      Variable.withBool(includeArchived),
    ];
    return _db.customSelect(
      sql,
      variables: variables,
      readsFrom: {_db.accounts, _db.transactions},
    );
  }

  List<AccountBalance> _toBalances(List<QueryRow> rows) => rows
      .map(
        (row) => AccountBalance(
          account: _toDomainRow(row),
          movementDelta: row.read<int>('movement_delta'),
        ),
      )
      .toList(growable: false);

  Future<Account?> findById(String id) async {
    final row = await (_db.select(
      _db.accounts,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  Future<String> create(AccountDraft draft) async {
    _ensureValid(draft);
    final id = newId();
    final now = utcNowIsoString();
    await _db
        .into(_db.accounts)
        .insert(
          db.AccountsCompanion.insert(
            id: id,
            name: draft.name.trim(),
            type: draft.type.dbValue,
            currencyCode: Value(draft.currencyCode),
            openingBalance: Value(draft.openingBalance),
            openingDate: FinancialDate.fromDateTime(draft.openingDate),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<void> update(String id, AccountDraft draft) async {
    _ensureValid(draft);
    await (_db.update(_db.accounts)..where((t) => t.id.equals(id))).write(
      db.AccountsCompanion(
        name: Value(draft.name.trim()),
        type: Value(draft.type.dbValue),
        openingBalance: Value(draft.openingBalance),
        openingDate: Value(FinancialDate.fromDateTime(draft.openingDate)),
        updatedAt: Value(utcNowIsoString()),
      ),
    );
  }

  Future<void> setArchived(String id, {required bool archived}) async {
    await (_db.update(_db.accounts)..where((t) => t.id.equals(id))).write(
      db.AccountsCompanion(
        isArchived: Value(archived),
        updatedAt: Value(utcNowIsoString()),
      ),
    );
  }

  void _ensureValid(AccountDraft draft) {
    final errors = draft.validate();
    if (errors.isNotEmpty) {
      throw AppFailure(errors.values.first);
    }
  }

  Account _toDomain(db.Account row) => Account(
    id: row.id,
    name: row.name,
    type: AccountType.fromDb(row.type),
    currencyCode: row.currencyCode,
    openingBalance: row.openingBalance,
    openingDate:
        FinancialDate.tryParse(row.openingDate) ?? DateTime(1970, 1, 1),
    isArchived: row.isArchived,
  );

  Account _toDomainRow(QueryRow row) => Account(
    id: row.read<String>('id'),
    name: row.read<String>('name'),
    type: AccountType.fromDb(row.read<String>('type')),
    currencyCode: row.read<String>('currency_code'),
    openingBalance: row.read<int>('opening_balance'),
    openingDate:
        FinancialDate.tryParse(row.read<String>('opening_date')) ??
        DateTime(1970, 1, 1),
    isArchived: row.read<bool>('is_archived'),
  );
}
