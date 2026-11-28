import 'package:flex/database/categories.dart';
import 'package:drift/drift.dart';
import 'package:flex/database/database.dart';

Future<Exercise?> getExerciseByName(
  AppDatabase database,
  String name, {
  bool includeArchived = false,
}) => _exerciseByName(
  database,
  name,
  includeArchived: includeArchived,
).getSingleOrNull();

Stream<Exercise?> watchExerciseByName(AppDatabase database, String name) =>
    _exerciseByName(database, name).watchSingleOrNull();

Selectable<Exercise> _exerciseByName(
  AppDatabase database,
  String name, {
  bool includeArchived = false,
}) => database.exercises.select()
  ..where(
    (exercise) =>
        exercise.name.equals(name) &
        (includeArchived
            ? const Constant(true)
            : exercise.archived.equals(false)),
  );

SimpleSelectStatement<$ExercisesTable, Exercise> _activeExercises(
  AppDatabase database,
) => database.exercises.select()
  ..where((exercise) => exercise.archived.equals(false))
  ..orderBy([(exercise) => OrderingTerm.asc(exercise.name)]);

Stream<List<String>> watchExerciseNames(AppDatabase database) =>
    _activeExercises(database).map((exercise) => exercise.name).watch();

Stream<List<Exercise>> watchExerciseCatalog(AppDatabase database) =>
    _activeExercises(database).watch();

List<Exercise> filterExerciseCatalog(
  Iterable<Exercise> exercises,
  Set<int> unavailableExerciseIds,
  String search,
) {
  final normalizedSearch = search.toLowerCase();
  return [
    for (final exercise in exercises)
      if (!unavailableExerciseIds.contains(exercise.id) &&
          exercise.name.toLowerCase().contains(normalizedSearch))
        exercise,
  ];
}

Future<String?> getExerciseCategoryName(
  AppDatabase database,
  Exercise exercise,
) async {
  final categoryId = exercise.categoryId;
  if (categoryId == null) return null;
  return (await (database.categories.select()
            ..where((category) => category.id.equals(categoryId)))
          .getSingleOrNull())
      ?.name;
}

Future<ExercisesCompanion> _definition(
  AppDatabase database, {
  required String name,
  required bool cardio,
  required String displayUnit,
  String? category,
  String? image,
  int? defaultRestDurationMs,
}) async => ExercisesCompanion.insert(
  name: name.trim(),
  kind: cardio ? 'cardio' : 'strength',
  displayUnit: displayUnit,
  categoryId: Value(await ensureCategoryId(database, category)),
  image: Value(image),
  defaultRestDurationMs: Value(defaultRestDurationMs),
);

Future<Exercise> createExerciseDefinition(
  AppDatabase database, {
  required String name,
  required bool cardio,
  required String displayUnit,
  String? category,
  String? image,
  int? defaultRestDurationMs,
  String? notes,
}) async => database.exercises.insertReturning(
  (await _definition(
    database,
    name: name,
    cardio: cardio,
    displayUnit: displayUnit,
    category: category,
    image: image,
    defaultRestDurationMs: defaultRestDurationMs,
  )).copyWith(notes: Value(notes)),
);

Future<Exercise> upsertExerciseDefinition(
  AppDatabase database,
  ExercisesCompanion definition,
) => database.exercises.insertReturning(
  definition,
  onConflict: DoUpdate((_) => definition, target: [database.exercises.name]),
);

Future<Exercise> syncExerciseDefinition(
  AppDatabase database,
  ExerciseSetView set,
) async => upsertExerciseDefinition(
  database,
  (await _definition(
    database,
    name: set.name,
    cardio: set.cardio,
    displayUnit: set.unit,
    category: set.category,
    image: set.image,
    defaultRestDurationMs: set.restMs,
  )).copyWith(archived: const Value(false)),
);

Future<void> _mergePlanExerciseReferences(
  AppDatabase database, {
  required int sourceId,
  required int targetId,
}) async {
  final sourceRows =
      await (database.planExercises.select()
            ..where((row) => row.exerciseId.equals(sourceId)))
          .get();

  for (final source in sourceRows) {
    final target =
        await (database.planExercises.select()..where(
              (row) =>
                  row.planId.equals(source.planId) &
                  row.exerciseId.equals(targetId),
            ))
            .getSingleOrNull();

    if (target == null) {
      await (database.planExercises.update()
            ..where((row) => row.id.equals(source.id)))
          .write(PlanExercisesCompanion(exerciseId: Value(targetId)));
      continue;
    }

    final preferSource = source.enabled && !target.enabled;
    await (database.planExercises.update()
          ..where((row) => row.id.equals(target.id)))
        .write(
          PlanExercisesCompanion(
            enabled: Value(target.enabled || source.enabled),
            maxSets: Value(
              preferSource ? source.maxSets : target.maxSets ?? source.maxSets,
            ),
            warmupSets: Value(
              preferSource
                  ? source.warmupSets
                  : target.warmupSets ?? source.warmupSets,
            ),
            timers: Value(preferSource ? source.timers : target.timers),
            sequence: Value(
              source.sequence < target.sequence
                  ? source.sequence
                  : target.sequence,
            ),
          ),
        );
    await (database.planExercises.delete()
          ..where((row) => row.id.equals(source.id)))
        .go();
  }
}

Future<void> _moveExerciseReferences(
  AppDatabase database,
  int sourceId,
  int targetId,
) async {
  await _mergePlanExerciseReferences(
    database,
    sourceId: sourceId,
    targetId: targetId,
  );
  await (database.exerciseSets.update()
        ..where((row) => row.exerciseId.equals(sourceId)))
      .write(ExerciseSetsCompanion(exerciseId: Value(targetId)));
}

Future<void> _deleteExercise(AppDatabase database, int id) =>
    (database.exercises.delete()..where((row) => row.id.equals(id))).go();

Future<void> updateExerciseDefinition(
  AppDatabase database, {
  required int exerciseId,
  required String name,
  required bool cardio,
  required String displayUnit,
  String? category,
  String? image,
  int? defaultRestDurationMs,
}) async {
  final definition = await _definition(
    database,
    name: name,
    cardio: cardio,
    displayUnit: displayUnit,
    category: category,
    image: image,
    defaultRestDurationMs: defaultRestDurationMs,
  );
  final target = await getExerciseByName(
    database,
    definition.name.value,
    includeArchived: true,
  );

  if (target == null || target.id == exerciseId) {
    await (database.exercises.update()
          ..where((row) => row.id.equals(exerciseId)))
        .write(definition);
    return;
  }

  await database.transaction(() async {
    await _moveExerciseReferences(database, exerciseId, target.id);
    await (database.exercises.update()
          ..where((row) => row.id.equals(target.id)))
        .write(
          definition.copyWith(
            name: Value(target.name),
            archived: const Value(false),
          ),
        );
    await _deleteExercise(database, exerciseId);
  });
}

/// Combines graph identities without deleting workout sets or plan memberships.
/// The kept exercise supplies graph settings, category, image and unit.
Future<void> mergeExerciseGraphs(
  AppDatabase database, {
  required Set<int> exerciseIds,
  required int keepExerciseId,
  required String name,
}) async {
  if (exerciseIds.length < 2 || !exerciseIds.contains(keepExerciseId)) {
    throw ArgumentError('Select at least two exercises and a name to keep.');
  }
  final trimmedName = name.trim();
  if (trimmedName.isEmpty) {
    throw ArgumentError('Enter a name for the merged graph.');
  }

  await database.transaction(() async {
    final exercises =
        await (database.exercises.select()
              ..where((row) => row.id.isIn(exerciseIds)))
            .get();
    if (exercises.length != exerciseIds.length) {
      throw StateError('One of the selected exercises no longer exists.');
    }

    final keep = exercises.singleWhere((row) => row.id == keepExerciseId);
    if (exercises.any(
      (row) =>
          row.kind != keep.kind ||
          (row.kind == 'cardio' && row.displayUnit != keep.displayUnit),
    )) {
      throw StateError('These exercises have incompatible types or units.');
    }

    final collision = await getExerciseByName(
      database,
      trimmedName,
      includeArchived: true,
    );
    if (collision != null && !exerciseIds.contains(collision.id)) {
      throw StateError('That name is already used by another exercise.');
    }

    for (final source in exercises) {
      if (source.id == keepExerciseId) continue;
      await _moveExerciseReferences(database, source.id, keepExerciseId);
      await _deleteExercise(database, source.id);
    }

    // Rename after removing source rows to satisfy the unique name index.
    await (database.exercises.update()
          ..where((row) => row.id.equals(keepExerciseId)))
        .write(
          ExercisesCompanion(
            name: Value(trimmedName),
            archived: const Value(false),
          ),
        );
  });
}

Future<void> updateExerciseGraphPreferences(
  AppDatabase database, {
  required int exerciseId,
  required String metric,
  required String period,
  required int limit,
  required bool timeBasedXAxis,
  required String? notes,
}) {
  return (database.exercises.update()
        ..where((row) => row.id.equals(exerciseId)))
      .write(
        ExercisesCompanion(
          graphMetric: Value(metric),
          graphPeriod: Value(period),
          graphLimit: Value(limit),
          graphTimeBasedXAxis: Value(timeBasedXAxis),
          notes: Value(notes),
        ),
      );
}
