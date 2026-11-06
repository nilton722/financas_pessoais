import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/files/app_files_provider.dart';
import '../../../core/formatters/date_formatter.dart';
import '../../transactions/domain/movement.dart';
import '../../transactions/presentation/transactions_providers.dart';
import '../data/report_export_service.dart';
import '../data/report_file_saver.dart';
import '../domain/report.dart';

enum ReportPreset {
  thisMonth('Este mês'),
  lastMonth('Mês anterior'),
  lastThreeMonths('Últimos 3 meses'),
  custom('Personalizado');

  const ReportPreset(this.label);

  final String label;
}

class ReportPeriod {
  const ReportPeriod({required this.from, required this.to});

  final DateTime from;
  final DateTime to;

  String get label =>
      '${FinancialDate.toDisplay(FinancialDate.fromDateTime(from))} a '
      '${FinancialDate.toDisplay(FinancialDate.fromDateTime(to))}';

  static ReportPeriod forPreset(ReportPreset preset, DateTime today) {
    final month = DateTime(today.year, today.month);
    final lastDay = DateTime(today.year, today.month + 1, 0);
    return switch (preset) {
      ReportPreset.thisMonth => ReportPeriod(from: month, to: lastDay),
      ReportPreset.lastMonth => ReportPeriod(
        from: DateTime(today.year, today.month - 1),
        to: DateTime(today.year, today.month, 0),
      ),
      ReportPreset.lastThreeMonths => ReportPeriod(
        from: DateTime(today.year, today.month - 2),
        to: lastDay,
      ),
      ReportPreset.custom => ReportPeriod(from: month, to: lastDay),
    };
  }
}

class ReportFilter {
  const ReportFilter({required this.preset, required this.period});

  final ReportPreset preset;
  final ReportPeriod period;
}

class ReportFilterController extends Notifier<ReportFilter> {
  @override
  ReportFilter build() => ReportFilter(
    preset: ReportPreset.thisMonth,
    period: ReportPeriod.forPreset(
      ReportPreset.thisMonth,
      FinancialDate.today(),
    ),
  );

  void setPreset(ReportPreset preset) {
    state = ReportFilter(
      preset: preset,
      period: ReportPeriod.forPreset(preset, FinancialDate.today()),
    );
  }

  void setRange(DateTime from, DateTime to) {
    final start = FinancialDate.dateOnly(from);
    final end = FinancialDate.dateOnly(to);
    state = ReportFilter(
      preset: ReportPreset.custom,
      period: ReportPeriod(
        from: start.isAfter(end) ? end : start,
        to: start.isAfter(end) ? start : end,
      ),
    );
  }
}

final reportFilterProvider =
    NotifierProvider<ReportFilterController, ReportFilter>(
      ReportFilterController.new,
    );

class ReportGroupModeController extends Notifier<ReportGroupMode> {
  @override
  ReportGroupMode build() => ReportGroupMode.category;

  void select(ReportGroupMode mode) => state = mode;
}

final reportGroupModeProvider =
    NotifierProvider<ReportGroupModeController, ReportGroupMode>(
      ReportGroupModeController.new,
    );

class ReportData {
  const ReportData({required this.items, required this.summary});

  final List<MovementListItem> items;
  final ReportSummary summary;
}

final reportDataProvider = FutureProvider<ReportData>((ref) async {
  final period = ref.watch(reportFilterProvider).period;
  final items = await ref
      .watch(transactionRepositoryProvider)
      .readMovements(MovementFilter(from: period.from, to: period.to));
  return ReportData(
    items: items,
    summary: ReportSummary.of(items, from: period.from, to: period.to),
  );
});

final reportExportServiceProvider = Provider<ReportExportService>(
  (ref) => ReportExportService(ref.watch(appFilesProvider)),
);

final reportFileSaverProvider = Provider<ReportFileSaver>(
  (ref) => saveReportFile,
);
