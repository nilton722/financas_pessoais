import 'dart:io';

import '../errors/app_failure.dart';
import '../files/app_files.dart';

/// Ficheiro de backup já escrito em disco.
class StoredBackup {
  const StoredBackup({
    required this.fileName,
    required this.path,
    required this.sizeBytes,
    required this.modifiedAt,
  });

  final String fileName;
  final String path;
  final int sizeBytes;
  final DateTime modifiedAt;
}

/// Acesso à pasta de backups. A escrita é feita em UTF-8 e o ficheiro só é
/// considerado concluído depois de `flush`; um erro de disco é propagado.
class BackupStorage {
  BackupStorage(this._files);

  final AppFiles _files;

  Future<Directory> directory() => _files.folder(AppFiles.backupsFolder);

  Future<StoredBackup> write(
    String contents, {
    required String prefix,
    DateTime? now,
  }) async {
    final folder = await directory();
    final timestamp = _fileTimestamp(now ?? DateTime.now());
    var fileName = '$prefix-$timestamp.json';
    var file = File('${folder.path}${Platform.pathSeparator}$fileName');
    var suffix = 1;
    while (await file.exists()) {
      fileName = '$prefix-$timestamp-$suffix.json';
      file = File('${folder.path}${Platform.pathSeparator}$fileName');
      suffix++;
    }
    try {
      await file.writeAsString(contents, flush: true);
    } on FileSystemException catch (error) {
      throw AppFailure(
        'Não foi possível escrever o ficheiro de backup.',
        cause: error,
      );
    }
    final stat = await file.stat();
    return StoredBackup(
      fileName: fileName,
      path: file.path,
      sizeBytes: stat.size,
      modifiedAt: stat.modified,
    );
  }

  Future<List<StoredBackup>> list() async {
    final folder = await directory();
    final entries = <StoredBackup>[];
    await for (final entity in folder.list(followLinks: false)) {
      if (entity is! File || !entity.path.toLowerCase().endsWith('.json')) {
        continue;
      }
      try {
        final stat = await entity.stat();
        entries.add(
          StoredBackup(
            fileName: entity.uri.pathSegments.last,
            path: entity.path,
            sizeBytes: stat.size,
            modifiedAt: stat.modified,
          ),
        );
      } on FileSystemException {
        // Um ficheiro ilegível não impede listar os restantes.
      }
    }
    entries.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return entries;
  }

  Future<String> read(StoredBackup backup) async {
    final folder = await directory();
    final file = File(
      '${folder.path}${Platform.pathSeparator}${backup.fileName}',
    );
    try {
      return await file.readAsString();
    } on FileSystemException catch (error) {
      throw AppFailure(
        'Não foi possível ler o ficheiro de backup.',
        cause: error,
      );
    }
  }
}

String _fileTimestamp(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}${two(local.month)}${two(local.day)}-'
      '${two(local.hour)}${two(local.minute)}${two(local.second)}-'
      '${local.millisecond.toString().padLeft(3, '0')}';
}
