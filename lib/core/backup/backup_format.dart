import 'dart:convert';

import '../app_info.dart';
import '../errors/app_failure.dart';

/// Formato de backup em JSON, independente da plataforma. Não é uma cópia
/// binária do SQLite: o conteúdo é validado e restaurado por tabelas, o que
/// permite testar o ciclo completo e impedir bases parcialmente restauradas.
const String backupFormat = 'financas_pessoais_backup';
const int backupFormatVersion = 1;

/// Versão do esquema que este formato compreende. Um backup de outra versão
/// é rejeitado em vez de ser interpretado à força.
const int backupSchemaVersion = 4;
const String backupAppVersion = AppInfo.version;
const String backupChecksumAlgorithm = 'fnv1a-32';

enum BackupValueType { text, optionalText, integer, optionalInteger, boolean }

const Map<String, BackupValueType> _accountColumns = {
  'id': BackupValueType.text,
  'name': BackupValueType.text,
  'type': BackupValueType.text,
  'currency_code': BackupValueType.text,
  'opening_balance': BackupValueType.integer,
  'opening_date': BackupValueType.text,
  'is_archived': BackupValueType.boolean,
  'created_at': BackupValueType.text,
  'updated_at': BackupValueType.text,
};

const Map<String, BackupValueType> _categoryColumns = {
  'id': BackupValueType.text,
  'name': BackupValueType.text,
  'kind': BackupValueType.text,
  'icon_key': BackupValueType.optionalText,
  'color_value': BackupValueType.optionalInteger,
  'is_system': BackupValueType.boolean,
  'is_archived': BackupValueType.boolean,
  'created_at': BackupValueType.text,
  'updated_at': BackupValueType.text,
};

const Map<String, BackupValueType> _transactionColumns = {
  'id': BackupValueType.text,
  'kind': BackupValueType.text,
  'account_id': BackupValueType.text,
  'destination_account_id': BackupValueType.optionalText,
  'category_id': BackupValueType.optionalText,
  'amount': BackupValueType.integer,
  'transaction_date': BackupValueType.text,
  'description': BackupValueType.optionalText,
  'notes': BackupValueType.optionalText,
  'created_at': BackupValueType.text,
  'updated_at': BackupValueType.text,
  'deleted_at': BackupValueType.optionalText,
};

const Map<String, BackupValueType> _plannedItemColumns = {
  'id': BackupValueType.text,
  'kind': BackupValueType.text,
  'account_id': BackupValueType.optionalText,
  'category_id': BackupValueType.optionalText,
  'amount': BackupValueType.integer,
  'due_date': BackupValueType.text,
  'description': BackupValueType.text,
  'status': BackupValueType.text,
  'transaction_id': BackupValueType.optionalText,
  'created_at': BackupValueType.text,
  'updated_at': BackupValueType.text,
};

const Map<String, BackupValueType> _plannedPaymentColumns = {
  'id': BackupValueType.text,
  'planned_item_id': BackupValueType.text,
  'transaction_id': BackupValueType.text,
  'amount': BackupValueType.integer,
  'payment_date': BackupValueType.text,
  'created_at': BackupValueType.text,
};

const Map<String, BackupValueType> _recurringRuleColumns = {
  'id': BackupValueType.text,
  'kind': BackupValueType.text,
  'account_id': BackupValueType.optionalText,
  'category_id': BackupValueType.optionalText,
  'amount': BackupValueType.integer,
  'frequency': BackupValueType.text,
  'start_date': BackupValueType.text,
  'end_date': BackupValueType.optionalText,
  'next_occurrence_date': BackupValueType.text,
  'description': BackupValueType.text,
  'is_active': BackupValueType.boolean,
  'created_at': BackupValueType.text,
  'updated_at': BackupValueType.text,
};

const Map<String, BackupValueType> _recurringOccurrenceColumns = {
  'id': BackupValueType.text,
  'rule_id': BackupValueType.text,
  'occurrence_date': BackupValueType.text,
  'planned_item_id': BackupValueType.optionalText,
  'transaction_id': BackupValueType.optionalText,
  'status': BackupValueType.text,
  'created_at': BackupValueType.text,
};

const Map<String, BackupValueType> _budgetColumns = {
  'id': BackupValueType.text,
  'category_id': BackupValueType.text,
  'period_type': BackupValueType.text,
  'period_start': BackupValueType.text,
  'limit_amount': BackupValueType.integer,
  'created_at': BackupValueType.text,
  'updated_at': BackupValueType.text,
};

const Map<String, BackupValueType> _savingsGoalColumns = {
  'id': BackupValueType.text,
  'name': BackupValueType.text,
  'target_amount': BackupValueType.integer,
  'target_date': BackupValueType.optionalText,
  'linked_account_id': BackupValueType.optionalText,
  'notes': BackupValueType.optionalText,
  'is_archived': BackupValueType.boolean,
  'created_at': BackupValueType.text,
  'updated_at': BackupValueType.text,
};

const Map<String, BackupValueType> _debtColumns = {
  'id': BackupValueType.text,
  'kind': BackupValueType.text,
  'counterparty': BackupValueType.optionalText,
  'description': BackupValueType.text,
  'original_amount': BackupValueType.integer,
  'due_date': BackupValueType.optionalText,
  'status': BackupValueType.text,
  'created_at': BackupValueType.text,
  'updated_at': BackupValueType.text,
};

const Map<String, BackupValueType> _debtPaymentColumns = {
  'id': BackupValueType.text,
  'debt_id': BackupValueType.text,
  'transaction_id': BackupValueType.text,
  'amount': BackupValueType.integer,
  'payment_date': BackupValueType.text,
  'created_at': BackupValueType.text,
};

const Map<String, BackupValueType> _settingColumns = {
  'key': BackupValueType.text,
  'value': BackupValueType.text,
  'updated_at': BackupValueType.text,
};

/// Tabelas de dados do utilizador, por ordem de inserção (pais antes dos
/// filhos). `schema_migrations` fica de fora: descreve a migração do ficheiro,
/// não o conteúdo do backup.
const Map<String, Map<String, BackupValueType>> backupTableSchemas = {
  'accounts': _accountColumns,
  'categories': _categoryColumns,
  'app_settings': _settingColumns,
  'transactions': _transactionColumns,
  'planned_items': _plannedItemColumns,
  'planned_item_payments': _plannedPaymentColumns,
  'recurring_rules': _recurringRuleColumns,
  'recurring_occurrences': _recurringOccurrenceColumns,
  'budgets': _budgetColumns,
  'savings_goals': _savingsGoalColumns,
  'debts': _debtColumns,
  'debt_payments': _debtPaymentColumns,
};

final List<String> backupTableNames = List<String>.unmodifiable(
  backupTableSchemas.keys,
);

final List<String> backupDeleteOrder = List<String>.unmodifiable(
  backupTableNames.reversed,
);

/// Instantâneo completo, já validado. As linhas mantêm os valores SQLite
/// nativos (texto, inteiro ou nulo), pelo que o restauro não perde tipos.
class BackupSnapshot {
  BackupSnapshot._({
    required this.createdAtRaw,
    required this.appVersion,
    required this.settings,
    required this.tables,
    required this.checksum,
  }) : counts = Map<String, int>.unmodifiable({
         for (final table in backupTableNames)
           table: (tables[table] ?? const []).length,
       });

  factory BackupSnapshot.create({
    required DateTime createdAt,
    required Map<String, String> settings,
    required Map<String, List<Map<String, Object?>>> tables,
  }) {
    final orderedTables = <String, List<Map<String, Object?>>>{
      for (final table in backupTableNames)
        table: List<Map<String, Object?>>.unmodifiable([
          for (final row in tables[table] ?? const <Map<String, Object?>>[])
            Map<String, Object?>.unmodifiable(
              _orderedRow(table, row, requireAllColumns: true),
            ),
        ]),
    };
    final createdAtRaw = createdAt.toUtc().toIso8601String();
    final orderedSettings = Map<String, String>.unmodifiable({
      for (final key in settings.keys.toList()..sort()) key: settings[key]!,
    });
    final checksum = _checksum(
      _payload(
        createdAtRaw: createdAtRaw,
        appVersion: backupAppVersion,
        settings: orderedSettings,
        tables: orderedTables,
      ),
    );
    return BackupSnapshot._(
      createdAtRaw: createdAtRaw,
      appVersion: backupAppVersion,
      settings: orderedSettings,
      tables: orderedTables,
      checksum: checksum,
    );
  }

  final String createdAtRaw;
  final String appVersion;
  final Map<String, String> settings;
  final Map<String, List<Map<String, Object?>>> tables;
  final Map<String, int> counts;
  final String checksum;

  DateTime get createdAt => DateTime.parse(createdAtRaw).toUtc();

  int get totalRows => counts.values.fold(0, (total, value) => total + value);

  String get currencyCode => settings['currency_code'] ?? 'XOF';
  String get locale => settings['locale'] ?? 'pt_PT';
  String get timeZone => settings['time_zone'] ?? 'Africa/Bissau';

  String toJsonString() {
    final payload = _payload(
      createdAtRaw: createdAtRaw,
      appVersion: appVersion,
      settings: settings,
      tables: tables,
    );
    return const JsonEncoder.withIndent('  ')
        .convert({...payload, 'checksum': checksum});
  }

  /// Lê e valida formato, versão, estrutura, contagens e checksum. Qualquer
  /// falha é apresentada como [AppFailure], sem expor dados financeiros.
  static BackupSnapshot decode(String source) {
    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const AppFailure('O ficheiro não é um backup JSON válido.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const AppFailure('O ficheiro não tem a estrutura de um backup.');
    }
    final map = Map<String, Object?>.from(decoded);

    if (map['format'] != backupFormat) {
      throw const AppFailure('O ficheiro não é um backup desta aplicação.');
    }
    final formatVersion = map['formatVersion'];
    if (formatVersion is! int) {
      throw const AppFailure('O backup não indica a versão do formato.');
    }
    if (formatVersion > backupFormatVersion) {
      throw const AppFailure(
        'O backup foi criado por uma versão mais recente da aplicação.',
      );
    }
    if (formatVersion < 1) {
      throw const AppFailure('Versão de formato de backup não suportada.');
    }
    final schemaVersion = map['schemaVersion'];
    if (schemaVersion is! int) {
      throw const AppFailure('O backup não indica a versão do esquema.');
    }
    if (schemaVersion != backupSchemaVersion) {
      throw AppFailure(
        'O backup usa o esquema v$schemaVersion; esta aplicação usa '
        'v$backupSchemaVersion.',
      );
    }
    final appVersion = map['appVersion'];
    if (appVersion is! String || appVersion.isEmpty) {
      throw const AppFailure('O backup não indica a versão da aplicação.');
    }
    final createdAtRaw = map['createdAt'];
    if (createdAtRaw is! String || DateTime.tryParse(createdAtRaw) == null) {
      throw const AppFailure('O backup não tem uma data de criação válida.');
    }
    final storedChecksum = map['checksum'];
    if (storedChecksum is! String || storedChecksum.isEmpty) {
      throw const AppFailure('O backup não tem checksum.');
    }

    final settingsRaw = map['settings'];
    if (settingsRaw is! Map<String, dynamic>) {
      throw const AppFailure('O backup não contém as configurações.');
    }
    final settings = <String, String>{};
    for (final entry in settingsRaw.entries) {
      final value = entry.value;
      if (value is! String) {
        throw AppFailure('Configuração inválida no backup: ${entry.key}.');
      }
      settings[entry.key] = value;
    }

    final tablesRaw = map['tables'];
    if (tablesRaw is! Map<String, dynamic>) {
      throw const AppFailure('O backup não contém as tabelas de dados.');
    }
    final tables = <String, List<Map<String, Object?>>>{};
    for (final table in backupTableNames) {
      final rowsRaw = tablesRaw[table];
      if (rowsRaw is! List) {
        throw AppFailure('O backup não contém a tabela $table.');
      }
      final rows = <Map<String, Object?>>[];
      for (final rowRaw in rowsRaw) {
        if (rowRaw is! Map<String, dynamic>) {
          throw AppFailure('Linha inválida na tabela $table.');
        }
        rows.add(_orderedRow(table, Map<String, Object?>.from(rowRaw)));
      }
      tables[table] = rows;
    }

    final countsRaw = map['counts'];
    if (countsRaw is! Map<String, dynamic>) {
      throw const AppFailure('O backup não contém as contagens.');
    }
    for (final table in backupTableNames) {
      final count = countsRaw[table];
      if (count is! int || count != tables[table]!.length) {
        throw AppFailure('Contagem inválida no backup para $table.');
      }
    }

    final orderedTables = <String, List<Map<String, Object?>>>{
      for (final table in backupTableNames)
        table: List<Map<String, Object?>>.unmodifiable(
          tables[table]!.map(Map<String, Object?>.unmodifiable),
        ),
    };
    final orderedSettings = Map<String, String>.unmodifiable({
      for (final key in settings.keys.toList()..sort()) key: settings[key]!,
    });
    final expectedChecksum = _checksum(
      _payload(
        createdAtRaw: createdAtRaw,
        appVersion: appVersion,
        settings: orderedSettings,
        tables: orderedTables,
      ),
    );
    if (expectedChecksum != storedChecksum) {
      throw const AppFailure(
        'O backup está corrompido: o checksum não confere.',
      );
    }

    return BackupSnapshot._(
      createdAtRaw: createdAtRaw,
      appVersion: appVersion,
      settings: orderedSettings,
      tables: orderedTables,
      checksum: storedChecksum,
    );
  }
}

Map<String, Object?> _orderedRow(
  String table,
  Map<String, Object?> row, {
  bool requireAllColumns = false,
}) {
  final schema = backupTableSchemas[table]!;
  final ordered = <String, Object?>{};
  for (final entry in schema.entries) {
    if (!row.containsKey(entry.key)) {
      if (requireAllColumns) {
        throw AppFailure(
          'O backup não contém a coluna ${entry.key} de $table.',
        );
      }
      ordered[entry.key] = null;
      continue;
    }
    final value = row[entry.key];
    if (!_matches(entry.value, value)) {
      throw AppFailure('Valor inválido para ${entry.key} em $table.');
    }
    ordered[entry.key] = value;
  }
  return ordered;
}

bool _matches(BackupValueType type, Object? value) => switch (type) {
  BackupValueType.text => value is String,
  BackupValueType.optionalText => value == null || value is String,
  BackupValueType.integer => value is int,
  BackupValueType.optionalInteger => value == null || value is int,
  BackupValueType.boolean => value is int && (value == 0 || value == 1),
};

Map<String, Object?> _payload({
  required String createdAtRaw,
  required String appVersion,
  required Map<String, String> settings,
  required Map<String, List<Map<String, Object?>>> tables,
}) => {
  'format': backupFormat,
  'formatVersion': backupFormatVersion,
  'schemaVersion': backupSchemaVersion,
  'createdAt': createdAtRaw,
  'appVersion': appVersion,
  'settings': {
    for (final key in settings.keys.toList()..sort()) key: settings[key],
  },
  'counts': {
    for (final table in backupTableNames) table: tables[table]!.length,
  },
  'tables': {
    for (final table in backupTableNames)
      table: [
        for (final row in tables[table]!)
          {
            for (final column in backupTableSchemas[table]!.keys)
              column: row[column],
          },
      ],
  },
};

/// FNV-1a de 32 bits. Deteta corrupção acidental; não é uma assinatura
/// criptográfica e não protege contra edição intencional do ficheiro.
String _checksum(Map<String, Object?> payload) {
  final bytes = utf8.encode(jsonEncode(payload));
  var hash = 0x811c9dc5;
  for (final byte in bytes) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
