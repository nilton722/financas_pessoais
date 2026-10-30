class SeedCategory {
  const SeedCategory({
    required this.id,
    required this.name,
    required this.kind,
    required this.iconKey,
  });

  final String id;
  final String name;
  final String kind;
  final String iconKey;
}

/// UUIDs estáveis: permitem semear de forma idempotente sem depender de
/// autoria em tempo de execução.
const List<SeedCategory> seedCategories = [
  SeedCategory(
    id: '00000000-0000-4000-8000-000000000101',
    name: 'Salário',
    kind: 'income',
    iconKey: 'salary',
  ),
  SeedCategory(
    id: '00000000-0000-4000-8000-000000000102',
    name: 'Trabalho independente',
    kind: 'income',
    iconKey: 'freelance',
  ),
  SeedCategory(
    id: '00000000-0000-4000-8000-000000000103',
    name: 'Outros rendimentos',
    kind: 'income',
    iconKey: 'other_income',
  ),
  SeedCategory(
    id: '00000000-0000-4000-8000-000000000201',
    name: 'Alimentação',
    kind: 'expense',
    iconKey: 'food',
  ),
  SeedCategory(
    id: '00000000-0000-4000-8000-000000000202',
    name: 'Transporte',
    kind: 'expense',
    iconKey: 'transport',
  ),
  SeedCategory(
    id: '00000000-0000-4000-8000-000000000203',
    name: 'Habitação',
    kind: 'expense',
    iconKey: 'housing',
  ),
  SeedCategory(
    id: '00000000-0000-4000-8000-000000000204',
    name: 'Saúde',
    kind: 'expense',
    iconKey: 'health',
  ),
  SeedCategory(
    id: '00000000-0000-4000-8000-000000000205',
    name: 'Educação',
    kind: 'expense',
    iconKey: 'education',
  ),
  SeedCategory(
    id: '00000000-0000-4000-8000-000000000206',
    name: 'Lazer',
    kind: 'expense',
    iconKey: 'leisure',
  ),
  SeedCategory(
    id: '00000000-0000-4000-8000-000000000207',
    name: 'Comunicações',
    kind: 'expense',
    iconKey: 'communications',
  ),
  SeedCategory(
    id: '00000000-0000-4000-8000-000000000208',
    name: 'Outras despesas',
    kind: 'expense',
    iconKey: 'other_expense',
  ),
];

const Map<String, String> seedSettings = {
  'currency_code': 'XOF',
  'locale': 'pt_PT',
  'time_zone': 'Africa/Bissau',
};

/// Valor de `color_value` inicial das categorias de sistema (Material teal).
const int seedCategoryColor = 0xFF00695C;
