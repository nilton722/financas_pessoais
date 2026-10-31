import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Barra de navegação inferior adaptativa.
///
/// O `NavigationBar` do Material 3 deixa a etiqueta quebrar em duas linhas
/// quando o destino não tem largura suficiente, o que desalinha a barra em
/// ecrãs estreitos ou com texto ampliado. Aqui cada etiqueta ocupa uma única
/// linha e encolhe apenas o necessário para caber, mantendo o ícone, o
/// indicador de seleção e as cores do tema.
class AppNavigationBar extends StatelessWidget {
  const AppNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<({IconData icon, String label})> destinations;

  static const double _height = 72;

  @override
  Widget build(BuildContext context) {
    final navigationTheme = Theme.of(context).navigationBarTheme;
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: navigationTheme.backgroundColor ?? scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      elevation: navigationTheme.elevation ?? 0,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: _height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final slot = constraints.maxWidth / destinations.length;
              final indicatorWidth = math
                  .min(slot * 0.8, 64.0)
                  .clamp(40.0, 64.0);
              return Row(
                children: [
                  for (var index = 0; index < destinations.length; index++)
                    Expanded(
                      child: _Destination(
                        icon: destinations[index].icon,
                        label: destinations[index].label,
                        selected: index == selectedIndex,
                        indicatorWidth: indicatorWidth,
                        onTap: () => onDestinationSelected(index),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Destination extends StatelessWidget {
  const _Destination({
    required this.icon,
    required this.label,
    required this.selected,
    required this.indicatorWidth,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final double indicatorWidth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final navigationTheme = theme.navigationBarTheme;
    final states = selected ? {WidgetState.selected} : const <WidgetState>{};

    final iconTheme =
        navigationTheme.iconTheme?.resolve(states) ??
        IconThemeData(
          size: 24,
          color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
        );
    final labelStyle =
        navigationTheme.labelTextStyle?.resolve(states) ??
        theme.textTheme.labelSmall?.copyWith(
          color: selected ? scheme.primary : scheme.onSurfaceVariant,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        );

    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.control,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xs,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  width: indicatorWidth,
                  height: 32,
                  decoration: BoxDecoration(
                    color: selected
                        ? navigationTheme.indicatorColor ??
                              scheme.primaryContainer
                        : Colors.transparent,
                    borderRadius: AppRadii.control,
                  ),
                  child: Icon(
                    icon,
                    size: iconTheme.size,
                    color: iconTheme.color,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      style: labelStyle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
