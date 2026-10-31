import 'package:flutter/widgets.dart';

import '../../core/security/device_auth_service.dart';

/// Política de bloqueio da aplicação.
///
/// O bloqueio é apenas de interface: não cifra a base SQLite nem os ficheiros.
/// O estado vive em memória; fechar a aplicação volta a bloquear.
class AppLockController extends ChangeNotifier {
  AppLockController(
    this._auth, {
    this.reLockAfter = const Duration(seconds: 60),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final DeviceAuthService _auth;
  final Duration reLockAfter;
  final DateTime Function() _now;

  bool _enabled = false;
  bool _configured = false;
  int _configurationVersion = 0;
  bool _locked = false;
  bool _supported = true;
  bool _authenticating = false;
  DeviceAuthOutcome? _lastOutcome;
  DateTime? _backgroundedAt;

  bool get enabled => _enabled;
  bool get configured => _configured;
  bool get locked => _locked;
  bool get supported => _supported;
  bool get authenticating => _authenticating;
  DeviceAuthOutcome? get lastOutcome => _lastOutcome;

  /// Aplica a preferência guardada. Só o primeiro valor bloqueia o arranque;
  /// ligar o interruptor durante a sessão aplica-se à próxima abertura.
  Future<void> configure(bool enabled) async {
    _enabled = enabled;
    final version = ++_configurationVersion;
    if (!_configured) {
      _configured = true;
      if (!enabled) {
        return;
      }
      final supported = await _auth.isSupported();
      if (version != _configurationVersion) {
        return;
      }
      _supported = supported;
      _locked = true;
      notifyListeners();
      return;
    }
    if (!enabled && _locked) {
      _locked = false;
      _lastOutcome = null;
      notifyListeners();
    }
  }

  void handleLifecycle(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _backgroundedAt ??= _now();
      return;
    }
    if (state != AppLifecycleState.resumed) {
      return;
    }
    final backgroundedAt = _backgroundedAt;
    _backgroundedAt = null;
    if (_enabled &&
        !_locked &&
        backgroundedAt != null &&
        _now().difference(backgroundedAt) >= reLockAfter) {
      _locked = true;
      _lastOutcome = null;
      notifyListeners();
    }
  }

  Future<bool> unlock() async {
    if (!_locked) {
      return true;
    }
    if (!_supported) {
      return openWithoutCredentials();
    }
    if (_authenticating) {
      return false;
    }
    _authenticating = true;
    _lastOutcome = null;
    notifyListeners();

    final outcome = await _auth.authenticate(
      reason: 'Desbloquear a Nô Dinheru',
    );

    _authenticating = false;
    _lastOutcome = outcome;
    if (outcome == DeviceAuthOutcome.success) {
      _locked = false;
    } else if (outcome == DeviceAuthOutcome.unsupported) {
      _supported = false;
    }
    notifyListeners();
    return !_locked;
  }

  /// Usado quando o dispositivo deixou de ter credenciais configuradas, para
  /// não deixar o utilizador preso fora da própria aplicação.
  bool openWithoutCredentials() {
    if (!_locked) {
      return true;
    }
    _locked = false;
    _lastOutcome = null;
    notifyListeners();
    return true;
  }
}
