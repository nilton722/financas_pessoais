/// Configuração local da aplicação. `timeZone` guarda um nome IANA e é
/// apenas um valor configurável nesta fase (sem conversões de fuso).
class AppSettings {
  const AppSettings({
    required this.currencyCode,
    required this.locale,
    required this.timeZone,
  });

  static const AppSettings defaults = AppSettings(
    currencyCode: 'XOF',
    locale: 'pt_PT',
    timeZone: 'Africa/Bissau',
  );

  final String currencyCode;
  final String locale;
  final String timeZone;
}
