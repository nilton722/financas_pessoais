import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

/// Cartão com cabeçalho opcional e ação alinhada à direita.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.title,
    this.leading,
    this.subtitle,
    this.action,
    this.padding = AppSpacing.card,
    this.color,
    this.divider = false,
  });

  final Widget child;
  final String? title;
  final Widget? leading;
  final String? subtitle;
  final Widget? action;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasHeader = title != null || leading != null || action != null;
    return Card(
      color: color,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasHeader)
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                action == null ? AppSpacing.lg : AppSpacing.xs,
                divider ? AppSpacing.sm : 0,
              ),
              child: Row(
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title != null)
                          Text(title!, style: theme.textTheme.titleMedium),
                        if (subtitle != null) ...[
                          const SizedBox(height: AppSpacing.xxs),
                          Text(subtitle!, style: theme.textTheme.bodySmall),
                        ],
                      ],
                    ),
                  ),
                  ?action,
                ],
              ),
            ),
          if (hasHeader && divider) const Divider(height: 1),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}
