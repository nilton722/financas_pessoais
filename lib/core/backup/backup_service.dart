import '../database/app_database.dart' as db;
import '../errors/app_failure.dart';
import 'backup_crypto.dart';
import 'backup_format.dart';
import 'backup_storage.dart';

class BackupListItem {
  const BackupListItem({
    required this.file,
    this.snapshot,
    this.error,
    this.encrypted = false,
  });

  final StoredBackup file;
  final BackupSnapshot? snapshot;
  final String? error;

  /// O ficheiro tem um envelope cifrado. O conteúdo só é validado depois de
  /// o utilizador indicar a frase-passe.
  final bool encrypted;

  bool get isValid => snapshot != null;

  int get totalRows => snapshot?.totalRows ?? 0;
}

class RestoreOutcome {
  const RestoreOutcome({required this.snapshot, required this.safetyBackup});

  final BackupSnapshot snapshot;
  final StoredBackup safetyBackup;
}

/// Conteúdo já validado e, quando aplicável, decifrado em memória.
class UnlockedBackup {
  const UnlockedBackup({
    required this.snapshot,
    required this.contents,
    required this.encrypted,
  });

  final BackupSnapshot snapshot;

  /// JSON simples pronto a restaurar, sem o envelope cifrado.
  final String contents;
  final bool encrypted;
}

/// Captura e restauro dos dados do utilizador. O restauro nunca substitui a
/// base antes de validar o ficheiro e de escrever uma cópia de segurança da
/// base atual; a substituição acontece numa única transação SQLite.
class BackupService {
  BackupService(this._db, this._storage);

  final db.AppDatabase _db;
  final BackupStorage _storage;

  Future<String> directoryPath() async => (await _storage.directory()).path;

  Future<BackupListItem> createBackup({
    DateTime? now,
    String? passphrase,
  }) async {
    final snapshot = await _capture(now: now);
    var contents = snapshot.toJsonString();
    if (passphrase != null) {
      contents = await encryptBackup(contents, passphrase);
    }
    final file = await _storage.write(contents, prefix: 'backup', now: now);
    return BackupListItem(
      file: file,
      snapshot: snapshot,
      encrypted: passphrase != null,
    );
  }

  Future<List<BackupListItem>> listBackups() async {
    final files = await _storage.list();
    final items = <BackupListItem>[];
    for (final file in files) {
      try {
        final contents = await _storage.read(file);
        if (isEncryptedBackup(contents)) {
          items.add(BackupListItem(file: file, encrypted: true));
          continue;
        }
        items.add(
          BackupListItem(file: file, snapshot: BackupSnapshot.decode(contents)),
        );
      } on AppFailure catch (failure) {
        items.add(BackupListItem(file: file, error: failure.message));
      }
    }
    return items;
  }

  /// Valida e decifra (quando necessário) um conteúdo em memória, sem alterar
  /// a base. É usado para mostrar os detalhes antes da confirmação.
  Future<UnlockedBackup> unlock(String contents, {String? passphrase}) async {
    if (isEncryptedBackup(contents)) {
      if (passphrase == null || passphrase.isEmpty) {
        throw const AppFailure(
          'Este backup está cifrado. Escreva a frase-passe para o abrir.',
        );
      }
      final plaintext = await decryptBackup(contents, passphrase);
      return UnlockedBackup(
        snapshot: BackupSnapshot.decode(plaintext),
        contents: plaintext,
        encrypted: true,
      );
    }
    return UnlockedBackup(
      snapshot: BackupSnapshot.decode(contents),
      contents: contents,
      encrypted: false,
    );
  }

  Future<BackupSnapshot> preview(String contents, {String? passphrase}) async {
    return (await unlock(contents, passphrase: passphrase)).snapshot;
  }

  /// Revalida o ficheiro imediatamente antes de restaurar, para que uma
  /// alteração externa entre a listagem e o toque em "Restaurar" não passe.
  Future<RestoreOutcome> restore(
    BackupListItem item, {
    String? passphrase,
  }) async {
    if (!item.isValid && !item.encrypted) {
      throw AppFailure(
        item.error ?? 'O backup não é válido e não foi restaurado.',
      );
    }
    final contents = await _storage.read(item.file);
    final snapshot = await preview(contents, passphrase: passphrase);
    return _restoreSnapshot(snapshot);
  }

  /// Restaura um backup escolhido fora da pasta da aplicação (seletor de
  /// ficheiros do sistema) ou já decifrado. O conteúdo é validado e
  /// substituído na mesma transação do restauro normal, com cópia de
  /// segurança prévia.
  Future<RestoreOutcome> restoreExternal(
    String contents, {
    String? passphrase,
  }) async {
    final snapshot = await preview(contents, passphrase: passphrase);
    return _restoreSnapshot(snapshot);
  }

  Future<RestoreOutcome> _restoreSnapshot(BackupSnapshot snapshot) async {
    final safetySnapshot = await _capture();
    final safetyFile = await _storage.write(
      safetySnapshot.toJsonString(),
      prefix: 'pre-restore',
    );
    await _apply(snapshot);
    return RestoreOutcome(snapshot: snapshot, safetyBackup: safetyFile);
  }

  Future<BackupSnapshot> _capture({DateTime? now}) async {
    final tables = <String, List<Map<String, Object?>>>{};
    for (final table in backupTableNames) {
      final columns = backupTableSchemas[table]!.keys.toList(growable: false);
      final selected = columns.map(_quoteIdentifier).join(', ');
      final rows = await _db
          .customSelect(
            'SELECT $selected FROM ${_quoteIdentifier(table)} ORDER BY rowid',
          )
          .get();
      tables[table] = [
        for (final row in rows)
          {for (final column in columns) column: row.data[column]},
      ];
    }

    final settings = <String, String>{};
    for (final row in tables['app_settings']!) {
      final key = row['key'];
      final value = row['value'];
      if (key is String && value is String) {
        settings[key] = value;
      }
    }

    return BackupSnapshot.create(
      createdAt: (now ?? DateTime.now()).toUtc(),
      settings: settings,
      tables: tables,
    );
  }

  Future<void> _apply(BackupSnapshot snapshot) async {
    try {
      await _db.transaction(() async {
        for (final table in backupDeleteOrder) {
          await _db.customStatement('DELETE FROM ${_quoteIdentifier(table)}');
        }
        for (final table in backupTableNames) {
          for (final row in snapshot.tables[table]!) {
            await _insert(table, row);
          }
        }
        for (final table in backupTableNames) {
          final expected = snapshot.counts[table]!;
          final row = await _db
              .customSelect(
                'SELECT COUNT(*) AS total FROM ${_quoteIdentifier(table)}',
              )
              .getSingle();
          if (row.read<int>('total') != expected) {
            throw AppFailure(
              'O restauro de $table ficou incompleto. A base atual foi '
              'mantida.',
            );
          }
        }
        final violations = await _db
            .customSelect('PRAGMA foreign_key_check')
            .get();
        if (violations.isNotEmpty) {
          throw const AppFailure(
            'O backup contém relações inválidas. A base atual foi mantida.',
          );
        }
      });
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw AppFailure(
        'Não foi possível restaurar o backup. A base atual não foi alterada.',
        cause: error,
      );
    }
  }

  Future<void> _insert(String table, Map<String, Object?> row) async {
    final schema = backupTableSchemas[table]!;
    final columns = schema.keys.toList(growable: false);
    final placeholders = List.filled(columns.length, '?').join(', ');
    final sql =
        'INSERT INTO ${_quoteIdentifier(table)} '
        '(${columns.map(_quoteIdentifier).join(', ')}) '
        'VALUES ($placeholders)';
    await _db.customStatement(sql, [for (final column in columns) row[column]]);
  }
}

String _quoteIdentifier(String identifier) => '"$identifier"';
