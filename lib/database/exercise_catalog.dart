import 'package:drift/drift.dart';
import 'package:flex/database/database.dart';

Future<int?> _categoryId(AppDatabase database, String? name) async {
  final trimmed = name?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  await database
      .into(database.categories)
      .insert(
        CategoriesCompanion.insert(name: trimmed),
        mode: InsertMode.insertOrIgnore,
      );
  return (await (database.categories.select()
            ..where((category) => category.name.equals(trimmed)))
          .getSingle())
      .id;
}

Future<Exercise?> getExerciseByName(AppDatabase database, String name) {
  return (database.exercises.select()..where(
        (exercise) =>
            exercise.name.equals(name) & exercise.archived.equals(false),
      ))
      .getSingleOrNull();
}

Future<List<String>> getExerciseNames(AppDatabase database) {
  return (database.exercises.select()
        ..where((exercise) => exercise.archived.equals(false))
        ..orderBy([(exercise) => OrderingTerm.asc(exercise.name)]))
      .map((exercise) => exercise.name)
      .get();
}

Stream<List<Exercise>> watchExerciseCatalog(AppDatabase database) {
  return (database.exercises.select()
        ..where((exercise) => exercise.archived.equals(false))
        ..orderBy([(exercise) => OrderingTerm.asc(exercise.name)]))
      .watch();
}

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

Stream<List<String>> watchExerciseNames(AppDatabase database) =>
    watchExerciseCatalog(
      database,
    ).map((rows) => rows.map((row) => row.name).toList());

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

Future<Exercise> createExerciseDefinition(
  AppDatabase database, {
  required String name,
  required bool cardio,
  required String displayUnit,
  String? category,
  String? image,
  int? defaultRestDurationMs,
  String? notes,
}) async {
  final trimmedName = name.trim();
  final id = await _categoryId(database, category);
  return database.exercises.insertReturning(
    ExercisesCompanion.insert(
      name: trimmedName,
      kind: cardio ? 'cardio' : 'strength',
      displayUnit: displayUnit,
      categoryId: Value(id),
      image: Value(image),
      defaultRestDurationMs: Value(defaultRestDurationMs),
      notes: Value(notes),
    ),
  );
}

Future<Exercise> syncExerciseDefinition(
  AppDatabase database, {
  required String name,
  required bool cardio,
  required String displayUnit,
  String? category,
  String? image,
  int? defaultRestDurationMs,
}) async {
  final existing = await getExerciseByName(database, name);
  if (existing == null) {
    return createExerciseDefinition(
      database,
      name: name,
      cardio: cardio,
      displayUnit: displayUnit,
      category: category,
      image: image,
      defaultRestDurationMs: defaultRestDurationMs,
    );
  }
  final categoryId = await _categoryId(database, category);
  await (database.exercises.update()
        ..where((row) => row.id.equals(existing.id)))
      .write(
        ExercisesCompanion(
          kind: Value(cardio ? 'cardio' : 'strength'),
          displayUnit: Value(displayUnit),
          categoryId: Value(categoryId),
          image: Value(image),
          defaultRestDurationMs: Value(defaultRestDurationMs),
        ),
      );
  return (database.exercises.select()
        ..where((row) => row.id.equals(existing.id)))
      .getSingle();
}

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
  final trimmedName = name.trim();
  final categoryId = await _categoryId(database, category);
  final target =
      await (database.exercises.select()
            ..where((row) => row.name.equals(trimmedName)))
          .getSingleOrNull();

  final definition = ExercisesCompanion(
    name: Value(trimmedName),
    kind: Value(cardio ? 'cardio' : 'strength'),
    displayUnit: Value(displayUnit),
    categoryId: Value(categoryId),
    image: Value(image),
    defaultRestDurationMs: Value(defaultRestDurationMs),
  );

  if (target == null || target.id == exerciseId) {
    await (database.exercises.update()
          ..where((row) => row.id.equals(exerciseId)))
        .write(definition);
    return;
  }

  await database.transaction(() async {
    await _mergePlanExerciseReferences(
      database,
      sourceId: exerciseId,
      targetId: target.id,
    );
    await (database.exerciseSets.update()
          ..where((row) => row.exerciseId.equals(exerciseId)))
        .write(ExerciseSetsCompanion(exerciseId: Value(target.id)));
    await (database.exercises.update()
          ..where((row) => row.id.equals(target.id)))
        .write(
          ExercisesCompanion(
            name: Value(target.name),
            kind: Value(cardio ? 'cardio' : 'strength'),
            displayUnit: Value(displayUnit),
            categoryId: Value(categoryId),
            image: Value(image),
            defaultRestDurationMs: Value(defaultRestDurationMs),
            archived: const Value(false),
          ),
        );
    await (database.exercises.delete()
          ..where((row) => row.id.equals(exerciseId)))
        .go();
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
