import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

/// Notificação de lembrete já calculada pela aplicação.
class LocalNotificationRequest {
  const LocalNotificationRequest({
    required this.id,
    required this.key,
    required this.when,
    required this.title,
    required this.body,
    required this.payload,
  });

  final int id;
  final String key;

  /// Data e hora locais, interpretadas no fuso configurado.
  final DateTime when;
  final String title;
  final String body;
  final String payload;
}

/// Fronteira entre a lógica de lembretes e o plugin do sistema. Permite
/// testar o agendamento sem mensagens reais.
abstract interface class LocalNotificationGateway {
  bool get isSupported;

  Future<bool> requestPermission();

  Future<bool> areNotificationsEnabled();

  /// Cancela apenas notificações ainda pendentes; as já entregues ficam na
  /// gaveta de notificações até o utilizador as dispensar.
  Future<void> cancelPending();

  Future<void> schedule(
    LocalNotificationRequest request, {
    required String timeZone,
  });
}

/// Implementação Android/iOS sobre `flutter_local_notifications`.
///
/// Não abre rede. No Android usa alarmes inexatos (`inexactAllowWhileIdle`),
/// pelo que não exige a permissão de alarmes exatos. O plugin volta a agendar
/// as notificações depois de um reinício através do recetor de arranque.
class FlutterLocalNotificationGateway implements LocalNotificationGateway {
  FlutterLocalNotificationGateway({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const String _channelId = 'reminders';
  static const String _channelName = 'Lembretes';
  static const String _channelDescription =
      'Vencimentos de compromissos e resumo mensal de orçamentos.';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  @override
  bool get isSupported {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> _ensureInitialized() async {
    if (!isSupported || _initialized) {
      return;
    }
    timezone_data.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_notify'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
    );
    _initialized = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> requestPermission() async {
    if (!isSupported) {
      return false;
    }
    await _ensureInitialized();
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _android?.requestNotificationsPermission();
      return await areNotificationsEnabled();
    }
    final granted = await _ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    return granted ?? false;
  }

  @override
  Future<bool> areNotificationsEnabled() async {
    if (!isSupported) {
      return false;
    }
    await _ensureInitialized();
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _android?.areNotificationsEnabled() ?? false;
    }
    final options = await _ios?.checkPermissions();
    return options?.isEnabled ?? false;
  }

  @override
  Future<void> cancelPending() async {
    if (!isSupported) {
      return;
    }
    await _ensureInitialized();
    await _plugin.cancelAllPendingNotifications();
  }

  @override
  Future<void> schedule(
    LocalNotificationRequest request, {
    required String timeZone,
  }) async {
    if (!isSupported) {
      return;
    }
    await _ensureInitialized();
    final location = _locationFor(timeZone);
    final scheduled = timezone.TZDateTime(
      location,
      request.when.year,
      request.when.month,
      request.when.day,
      request.when.hour,
      request.when.minute,
    );
    await _plugin.zonedSchedule(
      id: request.id,
      title: request.title,
      body: request.body,
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          icon: 'ic_stat_notify',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          visibility: NotificationVisibility.private,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: request.payload,
    );
  }

  timezone.Location _locationFor(String name) {
    try {
      return timezone.getLocation(name);
    } catch (_) {
      return timezone.UTC;
    }
  }
}
