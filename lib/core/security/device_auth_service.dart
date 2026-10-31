import 'package:local_auth/local_auth.dart';

/// Resultado de uma tentativa de desbloqueio com as credenciais do telefone.
enum DeviceAuthOutcome { success, canceled, failed, unsupported }

/// Abstração sobre o desbloqueio do dispositivo, para permitir testes sem o
/// plugin nativo.
abstract class DeviceAuthService {
  Future<bool> isSupported();

  Future<DeviceAuthOutcome> authenticate({required String reason});
}

/// Delega no sistema o pedido de PIN, padrão, palavra-passe ou biometria.
///
/// A aplicação nunca recebe nem guarda dados biométricos; apenas o resultado
/// da autenticação gerida pelo Android/iOS.
class LocalDeviceAuthService implements DeviceAuthService {
  LocalDeviceAuthService({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<DeviceAuthOutcome> authenticate({required String reason}) async {
    try {
      final authenticated = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
      return authenticated
          ? DeviceAuthOutcome.success
          : DeviceAuthOutcome.failed;
    } on LocalAuthException catch (error) {
      return switch (error.code) {
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.timeout => DeviceAuthOutcome.canceled,
        LocalAuthExceptionCode.noCredentialsSet ||
        LocalAuthExceptionCode.noBiometricHardware =>
          DeviceAuthOutcome.unsupported,
        _ => DeviceAuthOutcome.failed,
      };
    } catch (_) {
      return DeviceAuthOutcome.failed;
    }
  }
}
