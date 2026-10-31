import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tempo mínimo em segundo plano antes de voltar a pedir o desbloqueio.
///
/// É uma constante de produto; o provider permite encurtá-lo nos testes.
final appLockReLockAfterProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 60),
);
