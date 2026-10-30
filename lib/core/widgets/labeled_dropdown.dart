import 'package:flutter/material.dart';

/// Dropdown controlado com etiqueta e erro, sem `FormField` (o valor pode
/// chegar de forma assíncrona, ao editar registos existentes).
class LabeledDropdown<T> extends StatelessWidget {
  const LabeledDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.errorText,
    this.hint = 'Selecionar',
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? errorText;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InputDecorator(
      decoration: InputDecoration(labelText: label, errorText: errorText),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          isDense: true,
          value: value,
          hint: Text(
            hint,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
