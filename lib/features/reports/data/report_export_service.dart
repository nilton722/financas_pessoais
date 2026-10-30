import 'dart:convert';
import 'dart:io';

import '../../../core/files/app_files.dart';
import '../../../core/formatters/date_formatter.dart';
import '../../../core/utils/time.dart';
import '../../transactions/domain/movement.dart';
import 'report_csv.dart';

/// Escreve o relatório CSV na pasta de exportações da aplicação. O ficheiro
/// só é criado quando o utilizador pede a exportação.
class ReportExportService {
  ReportExportService(this._files);

  final AppFiles _files;

  Future<File> export({
    required DateTime from,
    required DateTime to,
    required List<MovementListItem> items,
    DateTime? now,
  }) async {
    final folder = await _files.folder(AppFiles.exportsFolder);
    final file = await _uniqueFile(
      folder,
      _fileName(from: from, to: to, now: now),
    );
    final sink = file.openWrite(encoding: utf8);
    try {
      sink.write(ReportCsv.encode(items));
      await sink.flush();
    } finally {
      await sink.close();
    }
    return file;
  }

  static String _fileName({
    required DateTime from,
    required DateTime to,
    DateTime? now,
  }) {
    final start = FinancialDate.fromDateTime(from).replaceAll('-', '');
    final end = FinancialDate.fromDateTime(to).replaceAll('-', '');
    final timestamp = utcNowIsoString(now: now)
        .replaceAll(RegExp(r'[-:]'), '')
        .replaceAll('.', '')
        .substring(0, 15);
    return 'relatorio-$start-$end-$timestamp.csv';
  }

  static Future<File> _uniqueFile(Directory folder, String name) async {
    var candidate = File('${folder.path}${Platform.pathSeparator}$name');
    var suffix = 1;
    while (await candidate.exists()) {
      final stem = name.substring(0, name.length - 4);
      candidate = File(
        '${folder.path}${Platform.pathSeparator}$stem-$suffix.csv',
      );
      suffix += 1;
    }
    return candidate;
  }
}
