import 'package:drift/drift.dart';

/// Registo audível das migrações aplicadas. Complementa o `user_version`
/// do SQLite, que o Drift usa como ponteiro interno de versão.
class SchemaMigrations extends Table {
  IntColumn get version => integer()();
  TextColumn get appliedAt => text()();

  @override
  Set<Column> get primaryKey => {version};

  @override
  List<String> get customConstraints => [
    "CHECK (applied_at GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*Z')",
  ];
}
