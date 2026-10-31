import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_startup.dart';
import 'splash_page.dart';
import 'splash_providers.dart';

/// Mantém o splash visível até a inicialização real terminar e a animação de
/// entrada completar, depois desvanece-o para revelar a aplicação.
class SplashGate extends ConsumerStatefulWidget {
  const SplashGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends ConsumerState<SplashGate>
    with TickerProviderStateMixin {
  static const Duration _entranceDuration = Duration(milliseconds: 1000);
  static const Duration _exitDuration = Duration(milliseconds: 320);

  late final AnimationController _entrance;
  late final AnimationController _exit;
  late final Animation<double> _exitOpacity;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(vsync: this, duration: _entranceDuration);
    _exit = AnimationController(vsync: this, duration: _exitDuration);
    _exitOpacity = Tween<double>(
      begin: 1,
      end: 0,
    ).animate(CurvedAnimation(parent: _exit, curve: Curves.easeOutCubic));
    _start();
  }

  Future<void> _start() async {
    final initialization = ref
        .read(appStartupProvider.future)
        .then<void>((_) {}, onError: (Object _, StackTrace _) {});

    await Future.wait<void>([_entrance.forward(), initialization]);
    if (!mounted) {
      return;
    }

    await _exit.forward();
    if (!mounted) {
      return;
    }
    ref.read(splashFinishedProvider.notifier).complete();
    setState(() => _visible = false);
  }

  @override
  void dispose() {
    _entrance.dispose();
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(excluding: _visible, child: widget.child),
        if (_visible)
          FadeTransition(
            opacity: _exitOpacity,
            child: AbsorbPointer(child: SplashPage(animation: _entrance)),
          ),
      ],
    );
  }
}
