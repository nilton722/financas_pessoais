import '../../../core/files/system_file_saver.dart';

typedef BackupFileSaver = Future<bool> Function({
  required String fileName,
  required String contents,
});

/// Abre o seletor do sistema para gravar o backup fora da pasta da aplicação.
///
/// O destino pode ser Downloads, Google Drive, OneDrive ou qualquer outro
/// fornecedor instalado; a escolha do utilizador decide se o ficheiro sai ou
/// não do telefone.
Future<bool> saveBackupFile({
  required String fileName,
  required String contents,
}) => saveFileWithSystemPicker(
  fileName: fileName,
  contents: contents,
  mimeType: 'application/json',
  dialogTitle: 'Guardar backup',
  failureMessage: 'Não foi possível guardar o backup.',
);
