import 'package:financas_pessoais/core/notifications/local_notification_gateway.dart';

/// Gateway em memória: guarda os pedidos agendados e permite simular
/// plataformas sem suporte, permissões negadas e notificações desligadas.
class FakeNotificationGateway implements LocalNotificationGateway {
  FakeNotificationGateway({
    this.supported = true,
    this.permissionGranted = true,
    this.systemEnabled = true,
  });

  bool supported;
  bool permissionGranted;
  bool systemEnabled;
  int permissionRequests = 0;
  int cancelCalls = 0;
  final List<LocalNotificationRequest> scheduled = [];
  final List<String> timeZones = [];

  @override
  bool get isSupported => supported;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    if (permissionGranted) {
      systemEnabled = true;
    }
    return permissionGranted;
  }

  @override
  Future<bool> areNotificationsEnabled() async => systemEnabled;

  @override
  Future<void> cancelPending() async {
    cancelCalls++;
    scheduled.clear();
  }

  @override
  Future<void> schedule(
    LocalNotificationRequest request, {
    required String timeZone,
  }) async {
    scheduled.add(request);
    timeZones.add(timeZone);
  }
}
