import 'dart:convert';

import 'package:file_picker/file_picker.dart';

import '../errors/app_failure.dart';

/// Abre o seletor do sistema para gravar um ficheiro fora da pasta da app.
///
/// No Android usa o Storage Access Framework (`ACTION_CREATE_DOCUMENT`): a
/// aplicação escreve apenas no ficheiro escolhido, sem permissões de
/// armazenamento. O destino pode ser Downloads, Google Drive, OneDrive ou
/// qualquer outro fornecedor instalado; a escolha do utilizador decide se o
/// ficheiro sai ou não do telefone.
///
/// Devolve `true` quando o ficheiro foi gravado e `false` quando o seletor foi
/// cancelado. Falhas do plugin são convertidas em [AppFailure] com
/// [failureMessage], sem expor dados financeiros.
Future<bool> saveFileWithSystemPicker({
  required String fileName,
  required String contents,
  required String mimeType,
  required String dialogTitle,
  required String failureMessage,
}) async {
  try {
    final uri = await FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      bytes: utf8.encode(contents),
      mimeType: mimeType,
    );
    return uri != null;
  } on AppFailure {
    rethrow;
  } catch (error) {
    throw AppFailure(failureMessage, cause: error);
  }
}
