import 'package:file_selector/file_selector.dart';

import '../../../core/errors/app_failure.dart';

/// Backup escolhido pelo utilizador fora da pasta da aplicação.
class PickedBackup {
  const PickedBackup({required this.fileName, required this.contents});

  final String fileName;
  final String contents;
}

typedef BackupFilePicker = Future<PickedBackup?> Function();

/// Abre o seletor de documentos do sistema para escolher um backup JSON.
///
/// No Android usa o Storage Access Framework: o utilizador autoriza apenas o
/// ficheiro escolhido, sem conceder permissões de armazenamento à aplicação.
Future<PickedBackup?> pickBackupFile() async {
  const group = XTypeGroup(
    label: 'Backup Nô Dinheru',
    extensions: ['json'],
    mimeTypes: ['application/json'],
    uniformTypeIdentifiers: ['public.json'],
  );
  try {
    final file = await openFile(acceptedTypeGroups: const [group]);
    if (file == null) {
      return null;
    }
    return PickedBackup(
      fileName: file.name,
      contents: await file.readAsString(),
    );
  } on AppFailure {
    rethrow;
  } catch (error) {
    throw AppFailure(
      'Não foi possível ler o ficheiro escolhido.',
      cause: error,
    );
  }
}
