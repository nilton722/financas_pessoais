import 'dart:async';

import 'package:financas_pessoais/core/security/device_auth_service.dart';

/// Autenticação simulada: devolve os resultados enfileirados ou fica pendente
/// até [complete] ser chamado, para inspecionar o ecrã de bloqueio.
class FakeDeviceAuthService implements DeviceAuthService {
  FakeDeviceAuthService({
    this.supported = true,
    List<DeviceAuthOutcome> outcomes = const [],
  }) : _outcomes = [...outcomes];

  bool supported;
  final List<DeviceAuthOutcome> _outcomes;
  final List<Completer<DeviceAuthOutcome>> _pending = [];
  int calls = 0;

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<DeviceAuthOutcome> authenticate({required String reason}) {
    calls++;
    if (_outcomes.isNotEmpty) {
      return Future.value(_outcomes.removeAt(0));
    }
    final completer = Completer<DeviceAuthOutcome>();
    _pending.add(completer);
    return completer.future;
  }

  void complete(DeviceAuthOutcome outcome) {
    _pending.removeAt(0).complete(outcome);
  }
}
