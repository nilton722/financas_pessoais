/// Preferência local dos lembretes do sistema. A hora é interpretada no fuso
/// configurado nas definições e não altera nenhum cálculo financeiro.
class ReminderSettings {
  const ReminderSettings({
    required this.enabled,
    required this.hour,
    required this.minute,
  });

  static const ReminderSettings defaults = ReminderSettings(
    enabled: false,
    hour: 9,
    minute: 0,
  );

  final bool enabled;
  final int hour;
  final int minute;

  String get timeLabel =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  ReminderSettings copyWith({bool? enabled, int? hour, int? minute}) {
    return ReminderSettings(
      enabled: enabled ?? this.enabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
    );
  }

  /// Lê `HH:mm`, ignorando valores inválidos e aplicando os limites de um
  /// dia. A preferência em falta usa as 09:00.
  static ReminderSettings fromStored({
    required bool enabled,
    required String? storedTime,
  }) {
    final defaults = ReminderSettings.defaults;
    final parts = storedTime?.split(':');
    if (parts == null || parts.length != 2) {
      return ReminderSettings(
        enabled: enabled,
        hour: defaults.hour,
        minute: defaults.minute,
      );
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return ReminderSettings(
        enabled: enabled,
        hour: defaults.hour,
        minute: defaults.minute,
      );
    }
    return ReminderSettings(enabled: enabled, hour: hour, minute: minute);
  }
}
