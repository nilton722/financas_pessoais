import '../../../core/notifications/local_notification_gateway.dart';
import '../../settings/data/app_settings_repository.dart';
import 'budget_repository.dart';
import 'planning_repository.dart';
import 'reminder_planner.dart';

/// Mantém as notificações do sistema alinhadas com a preferência e com os
/// dados locais. A sincronização é segura para chamar repetidamente: remove
/// apenas notificações pendentes e volta a agendar as mesmas datas estáveis.
class ReminderCoordinator {
  ReminderCoordinator({
    required AppSettingsRepository settingsRepository,
    required PlanningRepository planningRepository,
    required BudgetRepository budgetRepository,
    required LocalNotificationGateway notificationGateway,
  }) : _settings = settingsRepository,
       _planning = planningRepository,
       _budgets = budgetRepository,
       _gateway = notificationGateway;

  final AppSettingsRepository _settings;
  final PlanningRepository _planning;
  final BudgetRepository _budgets;
  final LocalNotificationGateway _gateway;
  final ReminderPlanner _planner = const ReminderPlanner();

  bool _syncing = false;
  bool _rerun = false;

  Future<void> sync() async {
    if (_syncing) {
      _rerun = true;
      return;
    }
    _syncing = true;
    try {
      do {
        _rerun = false;
        await _syncOnce();
      } while (_rerun);
    } finally {
      _syncing = false;
    }
  }

  Future<bool> setEnabled(bool enabled) async {
    try {
      if (!_gateway.isSupported) {
        return false;
      }
      if (enabled && !await _gateway.requestPermission()) {
        return false;
      }
      final current = await _settings.loadReminders();
      await _settings.saveReminders(current.copyWith(enabled: enabled));
      await sync();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> setTime(int hour, int minute) async {
    final current = await _settings.loadReminders();
    await _settings.saveReminders(current.copyWith(hour: hour, minute: minute));
    await sync();
  }

  Future<void> _syncOnce() async {
    if (!_gateway.isSupported) {
      return;
    }
    final reminders = await _settings.loadReminders();
    if (!reminders.enabled) {
      await _gateway.cancelPending();
      return;
    }
    if (!await _gateway.areNotificationsEnabled()) {
      await _gateway.cancelPending();
      return;
    }

    final now = DateTime.now();
    final items = await _planning.readItems(pendingOnly: true);
    final budgets = await _budgets.readMonth(now);
    final settings = await _settings.load();
    final notifications = _planner.build(
      items: items,
      budgets: budgets,
      settings: reminders,
      now: now,
    );

    await _gateway.cancelPending();
    for (final notification in notifications) {
      await _gateway.schedule(notification, timeZone: settings.timeZone);
    }
  }
}
