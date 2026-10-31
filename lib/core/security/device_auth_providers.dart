import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'device_auth_service.dart';

final deviceAuthServiceProvider = Provider<DeviceAuthService>(
  (ref) => LocalDeviceAuthService(),
);

/// Indica se o dispositivo tem credenciais configuradas para desbloqueio.
final deviceAuthSupportProvider = FutureProvider<bool>(
  (ref) => ref.watch(deviceAuthServiceProvider).isSupported(),
);
