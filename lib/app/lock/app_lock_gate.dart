import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/security/device_auth_providers.dart';
import '../../features/settings/presentation/settings_providers.dart';
import '../splash/splash_providers.dart';
import 'app_lock_controller.dart';
import 'lock_providers.dart';
import 'lock_screen.dart';

/// Mantém a aplicação bloqueada até o sistema confirmar o desbloqueio do
/// telefone, quando essa preferência está ativa.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  late final AppLockController _controller;
  bool? _preference;
  bool _wasLocked = false;
  bool _promptScheduled = false;
  bool _autoPromptDone = false;

  @override
  void initState() {
    super.initState();
    _controller = AppLockController(
      ref.read(deviceAuthServiceProvider),
      reLockAfter: ref.read(appLockReLockAfterProvider),
    )..addListener(_onControllerChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller
      ..removeListener(_onControllerChanged)
      ..dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _controller.handleLifecycle(state);
  }

  void _applyPreference(bool enabled) {
    if (_preference == enabled) {
      return;
    }
    _preference = enabled;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_controller.configure(enabled));
    });
  }

  void _onControllerChanged() {
    if (!mounted) {
      return;
    }
    if (_controller.locked && !_wasLocked) {
      FocusManager.instance.primaryFocus?.unfocus();
      _autoPromptDone = false;
      _schedulePrompt();
    }
    _wasLocked = _controller.locked;
    setState(() {});
  }

  void _schedulePrompt() {
    if (_autoPromptDone ||
        _promptScheduled ||
        !_controller.locked ||
        !_controller.supported ||
        !ref.read(splashFinishedProvider)) {
      return;
    }
    _promptScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _promptScheduled = false;
      if (!mounted) {
        return;
      }
      if (_controller.locked &&
          _controller.supported &&
          !_controller.authenticating) {
        _autoPromptDone = true;
        unawaited(_controller.unlock());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final preference = ref.watch(lockPreferenceProvider).value;
    if (preference != null) {
      _applyPreference(preference);
    }
    if (ref.watch(splashFinishedProvider)) {
      _schedulePrompt();
    }

    final locked = _controller.locked;
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(
          excluding: locked,
          child: AbsorbPointer(absorbing: locked, child: widget.child),
        ),
        if (locked)
          LockScreen(
            controller: _controller,
            onUnlock: () => unawaited(_controller.unlock()),
          ),
      ],
    );
  }
}
