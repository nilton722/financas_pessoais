import '../../../core/formatters/date_formatter.dart';
import '../../../core/formatters/percent_formatter.dart';

const List<String> _months = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];

String formatMonth(DateTime month) =>
    '${_months[month.month - 1]} ${month.year}';

String formatDate(DateTime date) =>
    FinancialDate.toDisplay(FinancialDate.fromDateTime(date));

String formatOptionalDate(DateTime? date, {String fallback = 'Sem data'}) =>
    date == null ? fallback : formatDate(date);

String formatPercentage(double percent) => PercentFormatter.format(percent);
