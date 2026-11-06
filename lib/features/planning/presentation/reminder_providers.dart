import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatters/date_formatter.dart';
import '../../../core/notifications/local_notification_gateway.dart';
import '../../settings/domain/reminder_settings.dart';
import '../../settings/presentation/settings_providers.dart';
import '../data/reminder_coordinator.dart';
import '../domain/budget.dart';
import 'planning_providers.dart';

final localNotificationGatewayProvider = Provider<LocalNotificationGateway>(
  (ref) => FlutterLocalNotificationGateway(),
);

final reminderSupportProvider = Provider<bool>(
  (ref) => ref.watch(localNotificationGatewayProvider).isSupported,
);

final reminderSettingsProvider = FutureProvider<ReminderSettings>(
  (ref) => ref.watch(appSettingsRepositoryProvider).loadReminders(),
);

/// Permissão de notificações do sistema, consultada sem pedir nada ao
/// utilizador. Serve para avisar quando a preferência veio de um backup e o
/// telefone ainda não autorizou os avisos.
final reminderNotificationsAllowedProvider = FutureProvider<bool>((ref) {
  final gateway = ref.watch(localNotificationGatewayProvider);
  if (!gateway.isSupported) {
    return false;
  }
  return gateway.areNotificationsEnabled();
});

final reminderCoordinatorProvider = Provider<ReminderCoordinator>(
  (ref) => ReminderCoordinator(
    settingsRepository: ref.watch(appSettingsRepositoryProvider),
    planningRepository: ref.watch(planningRepositoryProvider),
    budgetRepository: ref.watch(budgetRepositoryProvider),
    notificationGateway: ref.watch(localNotificationGatewayProvider),
  ),
);

/// Orçamentos do mês atual, independentes do mês que o utilizador está a
/// consultar em Planeamento.
final currentMonthBudgetsProvider = StreamProvider<List<Budget>>((ref) {
  final now = FinancialDate.today();
  return ref.watch(budgetRepositoryProvider).watchMonth(now);
});
