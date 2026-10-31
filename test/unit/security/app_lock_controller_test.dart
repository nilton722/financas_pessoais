import 'package:financas_pessoais/app/lock/app_lock_controller.dart';
import 'package:financas_pessoais/core/security/device_auth_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_device_auth.dart';

void main() {
  test('preferência desligada não bloqueia nem autentica', () async {
    final auth = FakeDeviceAuthService();
    final controller = AppLockController(auth);

    await controller.configure(false);

    expect(controller.locked, isFalse);
    expect(await controller.unlock(), isTrue);
    expect(auth.calls, 0);
  });

  test('arranque com preferência ligada exige desbloqueio', () async {
    final auth = FakeDeviceAuthService(outcomes: [DeviceAuthOutcome.success]);
    final controller = AppLockController(auth);

    await controller.configure(true);

    expect(controller.locked, isTrue);
    expect(controller.supported, isTrue);
    expect(await controller.unlock(), isTrue);
    expect(controller.locked, isFalse);
    expect(auth.calls, 1);
  });

  test('cancelar mantém o bloqueio e regista o resultado', () async {
    final auth = FakeDeviceAuthService(outcomes: [DeviceAuthOutcome.canceled]);
    final controller = AppLockController(auth);

    await controller.configure(true);

    expect(await controller.unlock(), isFalse);
    expect(controller.locked, isTrue);
    expect(controller.lastOutcome, DeviceAuthOutcome.canceled);
  });

  test('dispositivo sem credenciais abre com aviso', () async {
    final auth = FakeDeviceAuthService(supported: false);
    final controller = AppLockController(auth);

    await controller.configure(true);

    expect(controller.locked, isTrue);
    expect(controller.supported, isFalse);
    expect(await controller.unlock(), isTrue);
    expect(controller.locked, isFalse);
    expect(auth.calls, 0);
  });

  test('volta a bloquear depois de 60 segundos em segundo plano', () async {
    var now = DateTime(2026, 10, 31, 12);
    final auth = FakeDeviceAuthService(outcomes: [DeviceAuthOutcome.success]);
    final controller = AppLockController(auth, now: () => now);

    await controller.configure(true);
    await controller.unlock();
    controller.handleLifecycle(AppLifecycleState.paused);
    now = now.add(const Duration(seconds: 61));
    controller.handleLifecycle(AppLifecycleState.resumed);

    expect(controller.locked, isTrue);
    expect(controller.lastOutcome, isNull);
  });

  test('regresso rápido não volta a bloquear', () async {
    var now = DateTime(2026, 10, 31, 12);
    final auth = FakeDeviceAuthService(outcomes: [DeviceAuthOutcome.success]);
    final controller = AppLockController(auth, now: () => now);

    await controller.configure(true);
    await controller.unlock();
    controller.handleLifecycle(AppLifecycleState.paused);
    now = now.add(const Duration(seconds: 30));
    controller.handleLifecycle(AppLifecycleState.resumed);

    expect(controller.locked, isFalse);
  });

  test(
    'ligar o interruptor durante a sessão não bloqueia de imediato',
    () async {
      final auth = FakeDeviceAuthService();
      final controller = AppLockController(auth);

      await controller.configure(false);
      await controller.configure(true);

      expect(controller.locked, isFalse);
      expect(auth.calls, 0);
    },
  );

  test('desligar a preferência desbloqueia a sessão', () async {
    final auth = FakeDeviceAuthService();
    final controller = AppLockController(auth);

    await controller.configure(true);
    expect(controller.locked, isTrue);

    await controller.configure(false);

    expect(controller.locked, isFalse);
  });
}
