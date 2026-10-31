import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../data/app_settings_repository.dart';
import '../domain/app_settings.dart';

final appSettingsRepositoryProvider = Provider<AppSettingsRepository>(
  (ref) => AppSettingsRepository(ref.watch(appDatabaseProvider)),
);

final appSettingsProvider = FutureProvider<AppSettings>(
  (ref) => ref.watch(appSettingsRepositoryProvider).load(),
);

final lockPreferenceProvider = FutureProvider<bool>(
  (ref) => ref.watch(appSettingsRepositoryProvider).loadLockOnOpen(),
);
