import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/planning/presentation/planning_providers.dart';
import '../features/planning/presentation/reminder_providers.dart';

/// Mantém os lembretes do sistema sincronizados com os dados locais.
///
/// Só observa os streams de planeamento quando os lembretes estão ativos.
/// Falhas de notificações nunca bloqueiam a interface: a app continua a
/// funcionar e os alertas dentro da app mantêm-se.
class ReminderSyncHost extends ConsumerStatefulWidget {
  const ReminderSyncHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ReminderSyncHost> createState() => _ReminderSyncHostState();
}

class _ReminderSyncHostState extends ConsumerState<ReminderSyncHost> {
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    Future.microtask(_syncNow);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _scheduleSync() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _syncNow);
  }

  Future<void> _syncNow() async {
    if (!mounted) {
      return;
    }
    try {
      await ref.read(reminderCoordinatorProvider).sync();
    } catch (_) {
      // Os lembretes são acessórios; não devem afetar o uso da aplicação.
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(reminderSettingsProvider).value?.enabled ?? false;
    ref.listen(reminderSettingsProvider, (_, _) => _scheduleSync());
    if (enabled) {
      ref.listen(pendingPlannedItemsProvider, (_, _) => _scheduleSync());
      ref.listen(currentMonthBudgetsProvider, (_, _) => _scheduleSync());
    }
    return widget.child;
  }
}
