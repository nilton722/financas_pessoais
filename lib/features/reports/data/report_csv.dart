import '../../../core/formatters/date_formatter.dart';
import '../../transactions/domain/movement.dart';

/// Codificação CSV pronta para folhas de cálculo em português.
///
/// - UTF-8 com BOM (para o Excel reconhecer acentos);
/// - separador `;` e fim de linha CRLF;
/// - datas `DD/MM/YYYY` e montantes inteiros em FCFA;
/// - campos com `;`, aspas ou quebras de linha entre aspas.
abstract final class ReportCsv {
  static const String bom = '\uFEFF';
  static const String separator = ';';
  static const String lineEnding = '\r\n';

  static const List<String> header = [
    'Data',
    'Tipo',
    'Descrição',
    'Categoria',
    'Conta',
    'Conta de destino',
    'Montante (FCFA)',
    'Notas',
  ];

  static String encode(List<MovementListItem> items) {
    final buffer = StringBuffer(bom);
    buffer.write(header.map(_field).join(separator));
    buffer.write(lineEnding);
    for (final item in items) {
      final movement = item.movement;
      final values = [
        FinancialDate.toDisplay(FinancialDate.fromDateTime(movement.date)),
        movement.kind.label,
        movement.description ?? '',
        item.categoryName ?? '',
        item.accountName,
        item.destinationAccountName ?? '',
        movement.amount.toString(),
        movement.notes ?? '',
      ];
      buffer.write(values.map(_field).join(separator));
      buffer.write(lineEnding);
    }
    return buffer.toString();
  }

  static String _field(String value) {
    final needsQuotes =
        value.contains(separator) ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    if (!needsQuotes) {
      return value;
    }
    return '"${value.replaceAll('"', '""')}"';
  }
}
