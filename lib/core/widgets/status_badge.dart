import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

enum StatusTone { neutral, positive, warning, danger, info }

/// Etiqueta curta de estado, sempre acompanhada de texto.
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, {super.key, this.tone = StatusTone.neutral});

  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (background, foreground) = switch (tone) {
      StatusTone.neutral => (
        scheme.surfaceContainerHigh,
        scheme.onSurfaceVariant,
      ),
      StatusTone.positive => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      StatusTone.warning => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      StatusTone.danger => (scheme.errorContainer, scheme.onErrorContainer),
      StatusTone.info => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadii.badge,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
