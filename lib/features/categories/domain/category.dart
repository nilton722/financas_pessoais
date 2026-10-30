enum CategoryKind {
  income('income', 'Rendimento'),
  expense('expense', 'Despesa');

  const CategoryKind(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static CategoryKind fromDb(String value) => values.firstWhere(
    (kind) => kind.dbValue == value,
    orElse: () => CategoryKind.expense,
  );
}

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.kind,
    required this.isSystem,
    required this.isArchived,
  });

  final String id;
  final String name;
  final CategoryKind kind;
  final bool isSystem;
  final bool isArchived;
}

class CategoryDraft {
  const CategoryDraft({required this.name, required this.kind});

  final String name;
  final CategoryKind kind;

  Map<String, String> validate() {
    final errors = <String, String>{};
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      errors['name'] = 'Indique o nome da categoria.';
    } else if (trimmedName.length > 60) {
      errors['name'] = 'O nome não pode exceder 60 caracteres.';
    }
    return errors;
  }
}
