import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

/// Linha rótulo/valor usada em resumos e detalhes.
class AppDataRow extends StatelessWidget {
  const AppDataRow({
    super.key,
    required this.label,
    required this.value,
    this.emphasize = false,
    this.padding = const EdgeInsets.symmetric(vertical: AppSpacing.xs),
  });

  final String label;
  final Widget value;
  final bool emphasize;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: emphasize ? FontWeight.w600 : null,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: DefaultTextStyle.merge(
              style: theme.textTheme.bodyMedium!.copyWith(
                fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
                color: emphasize ? theme.colorScheme.error : null,
              ),
              textAlign: TextAlign.end,
              child: value,
            ),
          ),
        ],
      ),
    );
  }
}
