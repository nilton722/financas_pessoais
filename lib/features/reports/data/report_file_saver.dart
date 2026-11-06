import '../../../core/files/system_file_saver.dart';

typedef ReportFileSaver = Future<bool> Function({
  required String fileName,
  required String contents,
});

/// Abre o seletor do sistema para gravar o relatório CSV fora da pasta da app.
///
/// O ficheiro é o mesmo CSV já escrito em `exports`, com UTF-8 e BOM. A
/// aplicação não faz upload: se o destino for um serviço de nuvem, a
/// transferência é feita por esse serviço.
Future<bool> saveReportFile({
  required String fileName,
  required String contents,
}) => saveFileWithSystemPicker(
  fileName: fileName,
  contents: contents,
  mimeType: 'text/csv',
  dialogTitle: 'Guardar relatório CSV',
  failureMessage: 'Não foi possível guardar o relatório.',
);
