import 'package:drift/drift.dart';
import 'package:flex/database/category_summary.dart';
import 'package:flex/database/database.dart';
import 'package:flex/main.dart';

export 'package:flex/database/category_summary.dart';

/// Stores the reusable category names available for workout entries.
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
}

Future<void> createCategory(String name, {AppDatabase? database}) async {
  final target = database ?? db;
  await target.categories.insertOne(
    CategoriesCompanion.insert(name: name.trim()),
    mode: InsertMode.insertOrIgnore,
  );
}

Future<int?> ensureCategoryId(AppDatabase database, String? name) async {
  final trimmed = name?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  await createCategory(trimmed, database: database);
  return (await (database.categories.select()
            ..where((category) => category.name.equals(trimmed)))
          .getSingle())
      .id;
}

Future<void> deleteCategory(Category category) =>
    _replaceCategory(category, null);

Future<void> mergeCategory(Category source, Category target) =>
    _replaceCategory(source, target.id);

Future<void> _replaceCategory(Category source, int? targetId) {
  return db.transaction(() async {
    await (db.exercises.update()
          ..where((exercise) => exercise.categoryId.equals(source.id)))
        .write(ExercisesCompanion(categoryId: Value(targetId)));
    await (db.categories.delete()..where((entry) => entry.id.equals(source.id)))
        .go();
  });
}

/// Renames [category] everywhere it is used.
Future<void> renameCategory(Category category, String name) {
  final trimmedName = name.trim();
  if (trimmedName == category.name) return Future.value();

  return (db.categories.update()
        ..where((entry) => entry.id.equals(category.id)))
      .write(CategoriesCompanion(name: Value(trimmedName)));
}

/// Watches all categories together with their workout-entry usage counts.
Stream<List<CategorySummary>> watchCategorySummaries() {
  return db
      .customSelect(
        '''
          SELECT categories.id, categories.name, COUNT(exercises.id) AS usage_count
          FROM categories
          LEFT JOIN exercises ON exercises.category_id = categories.id
            AND exercises.archived = 0
          GROUP BY categories.id, categories.name
          ORDER BY categories.name COLLATE NOCASE
        ''',
        readsFrom: {db.categories, db.exercises},
      )
      .watch()
      .map(
        (rows) => rows
            .map(
              (row) => CategorySummary(
                category: Category(
                  id: row.read<int>('id'),
                  name: row.read<String>('name'),
                ),
                usageCount: row.read<int>('usage_count'),
              ),
            )
            .toList(),
      );
}

Selectable<String> _categoryNames() =>
    (db.select(db.categories)
          ..orderBy([(category) => OrderingTerm.asc(category.name)]))
        .map((category) => category.name);

Future<List<String>> getCategories() => _categoryNames().get();

Stream<List<String>> getCategoriesStream() => _categoryNames().watch();
