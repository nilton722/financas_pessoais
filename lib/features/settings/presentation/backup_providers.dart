import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backup/backup_service.dart';
import '../../../core/backup/backup_storage.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/files/app_files.dart';
import '../../../core/files/app_files_provider.dart';
import '../data/backup_file_picker.dart';
import '../data/backup_file_saver.dart';

final backupStorageProvider = Provider<BackupStorage>(
  (ref) => BackupStorage(ref.watch(appFilesProvider)),
);

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(
    ref.watch(appDatabaseProvider),
    ref.watch(backupStorageProvider),
  ),
);

final backupListProvider = FutureProvider<List<BackupListItem>>(
  (ref) => ref.watch(backupServiceProvider).listBackups(),
);

final backupFilePickerProvider = Provider<BackupFilePicker>(
  (ref) => pickBackupFile,
);

final backupFileSaverProvider = Provider<BackupFileSaver>(
  (ref) => saveBackupFile,
);

final appDataDirectoryProvider = FutureProvider<String>(
  (ref) async => (await ref.watch(appFilesProvider).root()).path,
);

final backupsDirectoryProvider = FutureProvider<String>(
  (ref) async => (await ref.watch(backupStorageProvider).directory()).path,
);

final exportsDirectoryProvider = FutureProvider<String>(
  (ref) async =>
      (await ref.watch(appFilesProvider).folder(AppFiles.exportsFolder)).path,
);
