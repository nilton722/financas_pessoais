import '../../../core/formatters/date_formatter.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/notifications/local_notification_gateway.dart';
import '../../settings/domain/reminder_settings.dart';
import '../domain/budget.dart';
import '../domain/planned_item.dart';

/// Calcula os lembretes do sistema a partir do estado atual.
///
/// As datas são eventos de calendário estáveis (véspera, vencimento e último
/// dia do mês), para que reagendar após cada alteração substitua exatamente as
/// mesmas notificações e não produza avisos repetidos.
class ReminderPlanner {
  const ReminderPlanner();

  static const int horizonDays = 365;

  List<LocalNotificationRequest> build({
    required List<PlannedItem> items,
    required List<Budget> budgets,
    required ReminderSettings settings,
    required DateTime now,
  }) {
    if (!settings.enabled) {
      return const [];
    }
    final today = FinancialDate.dateOnly(now);
    final limit = today.add(const Duration(days: horizonDays));
    final notifications = <LocalNotificationRequest>[];

    for (final item in items) {
      if (!item.isOpen) {
        continue;
      }
      final due = FinancialDate.dateOnly(item.dueDate);
      if (due.isBefore(today) || due.isAfter(limit)) {
        continue;
      }
      final dayBefore = due.subtract(const Duration(days: 1));
      if (!dayBefore.isBefore(today)) {
        _addCommitment(
          notifications,
          item,
          when: _atTime(dayBefore, settings),
          now: now,
          tomorrow: true,
        );
      }
      _addCommitment(
        notifications,
        item,
        when: _atTime(due, settings),
        now: now,
        tomorrow: false,
      );
    }

    final exceeded = budgets
        .where(
          (budget) =>
              budget.periodStart.year == now.year &&
              budget.periodStart.month == now.month &&
              budget.isExceeded,
        )
        .toList(growable: false);
    if (exceeded.isNotEmpty) {
      final monthEnd = DateTime(now.year, now.month + 1, 0);
      final when = _atTime(monthEnd, settings);
      if (when.isAfter(now)) {
        final key = 'budget-summary:${now.year}-${now.month}';
        notifications.add(
          LocalNotificationRequest(
            id: _stableId(key),
            key: key,
            when: when,
            title: 'Orçamentos do mês',
            body: _budgetBody(exceeded),
            payload: '/planning/budgets',
          ),
        );
      }
    }

    notifications.sort((a, b) => a.when.compareTo(b.when));
    return notifications;
  }

  void _addCommitment(
    List<LocalNotificationRequest> notifications,
    PlannedItem item, {
    required DateTime when,
    required DateTime now,
    required bool tomorrow,
  }) {
    if (!when.isAfter(now)) {
      return;
    }
    final key =
        'commitment:${item.id}:${FinancialDate.fromDateTime(item.dueDate)}:'
        '${tomorrow ? 'before' : 'due'}';
    final isIncome = item.kind == PlannedItemKind.income;
    final action = isIncome ? 'Receber' : 'Pagar';
    final account = item.accountName == null ? '' : ' · ${item.accountName}';
    notifications.add(
      LocalNotificationRequest(
        id: _stableId(key),
        key: key,
        when: when,
        title: isIncome
            ? 'Rendimento previsto ${tomorrow ? 'amanhã' : 'hoje'}'
            : 'Compromisso vence ${tomorrow ? 'amanhã' : 'hoje'}',
        body:
            '$action: ${item.description} · '
            '${MoneyFormatter.formatXof(item.remaining)}$account',
        payload: '/planning/commitments',
      ),
    );
  }

  String _budgetBody(List<Budget> exceeded) {
    final names = <String>[];
    for (final budget in exceeded) {
      if (!names.contains(budget.categoryName)) {
        names.add(budget.categoryName);
      }
    }
    if (names.length == 1) {
      return '${names.single} ultrapassou o limite mensal.';
    }
    final shown = names.take(3).join(', ');
    final extra = names.length > 3 ? ' e mais ${names.length - 3}' : '';
    return '${names.length} orçamentos ultrapassaram o limite: '
        '$shown$extra.';
  }

  DateTime _atTime(DateTime day, ReminderSettings settings) =>
      DateTime(day.year, day.month, day.day, settings.hour, settings.minute);

  /// Identificador estável (31 bits) para que reagendar substitua a mesma
  /// notificação em vez de criar duplicados.
  int _stableId(String key) {
    var hash = 0x811c9dc5;
    for (final unit in key.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }
}
