import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/brand_colors.dart';

/// Ecrã de abertura da marca.
///
/// A composição segue a referência oficial: fundo esmeralda, ícone dentro de
/// um quadrado branco arredondado, nome, slogan e identificação. A animação é
/// conduzida por [animation] e não bloqueia a inicialização da aplicação.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key, required this.animation});

  final Animation<double> animation;

  static const String name = 'Nô Dinheru';
  static const String slogan = 'O teu dinheiro, sob controlo.';
  static const String identification = 'Finanças pessoais • Guiné-Bissau';

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final entrance = reduceMotion
        ? const AlwaysStoppedAnimation<double>(1)
        : animation;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: BrandColors.green,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Semantics(
        label: '$name. $slogan $identification.',
        container: true,
        child: ExcludeSemantics(
          child: ColoredBox(
            key: const Key('splash-screen'),
            color: BrandColors.green,
            // O builder do MaterialApp fica acima do Material/Navigator; sem
            // isto, o texto herdaria o estilo de erro do WidgetsApp (monospace
            // e sublinhado) em vez da tipografia da aplicação.
            child: DefaultTextStyle(
              style:
                  (Theme.of(context).textTheme.bodyMedium ?? const TextStyle())
                      .copyWith(
                        color: BrandColors.white,
                        decoration: TextDecoration.none,
                      ),
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final shortest = constraints.biggest.shortestSide;
                    final tileSize = (shortest * 0.36).clamp(104.0, 156.0);
                    final nameSize = (shortest * 0.087).clamp(30.0, 40.0);
                    final sloganSize = (shortest * 0.044).clamp(16.0, 20.0);
                    final identificationSize = (shortest * 0.0315).clamp(
                      12.0,
                      14.0,
                    );
                    final iconGap = (shortest * 0.075).clamp(24.0, 34.0);
                    final minHeight = math.max(0.0, constraints.maxHeight - 48);

                    final iconProgress = CurvedAnimation(
                      parent: entrance,
                      curve: const Interval(
                        0,
                        0.55,
                        curve: Curves.easeOutCubic,
                      ),
                    );

                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 24,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: minHeight),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FadeTransition(
                              opacity: iconProgress,
                              child: ScaleTransition(
                                scale: Tween<double>(
                                  begin: 0.92,
                                  end: 1,
                                ).animate(iconProgress),
                                child: _IconTile(size: tileSize),
                              ),
                            ),
                            SizedBox(height: iconGap),
                            _reveal(
                              entrance,
                              start: 0.28,
                              end: 0.7,
                              child: Text(
                                name,
                                key: const Key('splash-name'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: nameSize,
                                  height: 1.1,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.4,
                                  color: BrandColors.white,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _reveal(
                              entrance,
                              start: 0.48,
                              end: 0.86,
                              child: Text(
                                slogan,
                                key: const Key('splash-slogan'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: sloganSize,
                                  height: 1.3,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.1,
                                  color: const Color(0xFFEBF5F2),
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            _reveal(
                              entrance,
                              start: 0.62,
                              end: 1,
                              child: Text(
                                identification,
                                key: const Key('splash-tagline'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: identificationSize,
                                  height: 1.3,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: 0.2,
                                  color: const Color(0xFFB0D6CA),
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _reveal(
    Animation<double> entrance, {
    required double start,
    required double end,
    required Widget child,
  }) {
    final progress = CurvedAnimation(
      parent: entrance,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: progress,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(progress),
        child: child,
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('splash-icon-tile'),
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.115),
      decoration: BoxDecoration(
        color: BrandColors.white,
        borderRadius: BorderRadius.circular(size * 0.23),
        boxShadow: [
          BoxShadow(
            color: const Color(0x40000000),
            blurRadius: size * 0.16,
            offset: Offset(0, size * 0.05),
          ),
        ],
      ),
      child: Image.asset(
        'assets/branding/no_dinheru_icon.png',
        key: const Key('splash-icon'),
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        cacheWidth: 512,
      ),
    );
  }
}
