import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/presentation/settings_providers.dart';

/// Inicialização que o splash aguarda antes de revelar a aplicação.
///
/// Abre a base SQLite local (com as migrações pendentes), carrega as
/// definições guardadas e a preferência de bloqueio. Não substitui a
/// autenticação nem altera a navegação.
final appStartupProvider = FutureProvider<void>((ref) async {
  await ref.watch(appSettingsProvider.future);
  await ref.watch(lockPreferenceProvider.future);
});
