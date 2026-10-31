import 'dart:convert';

import 'package:file_picker/file_picker.dart';

import '../../../core/errors/app_failure.dart';

typedef BackupFileSaver = Future<bool> Function({
  required String fileName,
  required String contents,
});

/// Abre o seletor do sistema para gravar o backup fora da pasta da aplicação.
///
/// No Android usa o Storage Access Framework (`ACTION_CREATE_DOCUMENT`): a
/// aplicação escreve apenas no ficheiro escolhido, sem permissões de
/// armazenamento. O destino pode ser Downloads, Google Drive, OneDrive ou
/// qualquer outro fornecedor instalado; a escolha do utilizador decide se o
/// ficheiro sai ou não do telefone.
Future<bool> saveBackupFile({
  required String fileName,
  required String contents,
}) async {
  try {
    final uri = await FilePicker.saveFile(
      dialogTitle: 'Guardar backup',
      fileName: fileName,
      bytes: utf8.encode(contents),
      mimeType: 'application/json',
    );
    return uri != null;
  } on AppFailure {
    rethrow;
  } catch (error) {
    throw AppFailure('Não foi possível guardar o backup.', cause: error);
  }
}
