import '../database/app_database.dart' as db;
import '../errors/app_failure.dart';
import 'backup_format.dart';
import 'backup_storage.dart';

class BackupListItem {
  const BackupListItem({required this.file, this.snapshot, this.error});

  final StoredBackup file;
  final BackupSnapshot? snapshot;
  final String? error;

  bool get isValid => snapshot != null;

  int get totalRows => snapshot?.totalRows ?? 0;
}

class RestoreOutcome {
  const RestoreOutcome({required this.snapshot, required this.safetyBackup});

  final BackupSnapshot snapshot;
  final StoredBackup safetyBackup;
}

/// Captura e restauro dos dados do utilizador. O restauro nunca substitui a
/// base antes de validar o ficheiro e de escrever uma cópia de segurança da
/// base atual; a substituição acontece numa única transação SQLite.
class BackupService {
  BackupService(this._db, this._storage);

  final db.AppDatabase _db;
  final BackupStorage _storage;

  Future<String> directoryPath() async => (await _storage.directory()).path;

  Future<BackupListItem> createBackup({DateTime? now}) async {
    final snapshot = await _capture(now: now);
    final file = await _storage.write(
      snapshot.toJsonString(),
      prefix: 'backup',
      now: now,
    );
    return BackupListItem(file: file, snapshot: snapshot);
  }

  Future<List<BackupListItem>> listBackups() async {
    final files = await _storage.list();
    final items = <BackupListItem>[];
    for (final file in files) {
      try {
        final contents = await _storage.read(file);
        items.add(
          BackupListItem(file: file, snapshot: BackupSnapshot.decode(contents)),
        );
      } on AppFailure catch (failure) {
        items.add(BackupListItem(file: file, error: failure.message));
      }
    }
    return items;
  }

  /// Revalida o ficheiro imediatamente antes de restaurar, para que uma
  /// alteração externa entre a listagem e o toque em "Restaurar" não passe.
  Future<RestoreOutcome> restore(BackupListItem item) async {
    if (!item.isValid) {
      throw AppFailure(
        item.error ?? 'O backup não é válido e não foi restaurado.',
      );
    }
    final contents = await _storage.read(item.file);
    final snapshot = BackupSnapshot.decode(contents);
    return _restoreSnapshot(snapshot);
  }

  /// Restaura um backup escolhido fora da pasta da aplicação (seletor de
  /// ficheiros do sistema). O conteúdo é validado e substituído na mesma
  /// transação do restauro normal, com cópia de segurança prévia.
  Future<RestoreOutcome> restoreExternal(String contents) async {
    final snapshot = BackupSnapshot.decode(contents);
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
