import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart' as db;
import '../../../core/errors/app_failure.dart';
import '../../../core/utils/id.dart';
import '../../../core/utils/time.dart';
import '../domain/category.dart';

class CategoryRepository {
  CategoryRepository(this._db);

  final db.AppDatabase _db;

  Stream<List<Category>> watchAll({
    bool includeArchived = false,
    CategoryKind? kind,
  }) {
    final query = _db.select(_db.categories)
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
    if (!includeArchived) {
      query.where((t) => t.isArchived.equals(false));
    }
    if (kind != null) {
      query.where((t) => t.kind.equals(kind.dbValue));
    }
    return query.watch().map(
      (rows) => rows.map(_toDomain).toList(growable: false),
    );
  }

  Future<Category?> findById(String id) async {
    final row = await (_db.select(
      _db.categories,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  Future<String> create(CategoryDraft draft) async {
    _ensureValid(draft);
    await _ensureUniqueName(draft.kind, draft.name.trim());
    final id = newId();
    final now = utcNowIsoString();
    await _db
        .into(_db.categories)
        .insert(
          db.CategoriesCompanion.insert(
            id: id,
            name: draft.name.trim(),
            kind: draft.kind.dbValue,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<void> update(String id, CategoryDraft draft) async {
    _ensureValid(draft);
    await _ensureUniqueName(draft.kind, draft.name.trim(), excludeId: id);
    await (_db.update(_db.categories)..where((t) => t.id.equals(id))).write(
      db.CategoriesCompanion(
        name: Value(draft.name.trim()),
        updatedAt: Value(utcNowIsoString()),
      ),
    );
  }

  /// Arquivar mantém a categoria referenciada por movimentos existentes;
  /// apenas impede novas utilizações.
  Future<void> setArchived(String id, {required bool archived}) async {
    await (_db.update(_db.categories)..where((t) => t.id.equals(id))).write(
      db.CategoriesCompanion(
        isArchived: Value(archived),
        updatedAt: Value(utcNowIsoString()),
      ),
    );
  }

  void _ensureValid(CategoryDraft draft) {
    final errors = draft.validate();
    if (errors.isNotEmpty) {
      throw AppFailure(errors.values.first);
    }
  }

  Future<void> _ensureUniqueName(
    CategoryKind kind,
    String name, {
    String? excludeId,
  }) async {
    final query = _db.select(_db.categories)
      ..where(
        (t) =>
            t.kind.equals(kind.dbValue) &
            t.name.equals(name) &
            t.isArchived.equals(false),
      );
    final rows = await query.get();
    final clashes = rows.where((row) => row.id != excludeId);
    if (clashes.isNotEmpty) {
      throw const AppFailure(
        'Já existe uma categoria ativa com esse nome e tipo.',
      );
    }
  }

  Category _toDomain(db.Category row) => Category(
    id: row.id,
    name: row.name,
    kind: CategoryKind.fromDb(row.kind),
    isSystem: row.isSystem,
    isArchived: row.isArchived,
  );
}
