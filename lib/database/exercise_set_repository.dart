import 'package:drift/drift.dart';
import 'package:flex/constants.dart';
import 'package:flex/database/body_weight_repository.dart';
import 'package:flex/database/database.dart';
import 'package:flex/measurement_units.dart';

export 'package:flex/measurement_units.dart';

export 'package:flex/database/previous_exercise_set.dart';
export 'package:flex/database/previous_exercise_day.dart';

/// Converts a stored distance in metres to the exercise display unit.
double displayDistance(String unit, double? distanceMetres) {
  if (distanceMetres == null) return 0;
  return switch (unit) {
    'km' => distanceMetres / 1000,
    'mi' => distanceMetres / 1609.344,
    _ => distanceMetres,
  };
}

/// Converts a displayed distance to metres.
double? distanceMetres(String unit, double value) {
  return switch (unit) {
    'm' => value,
    'km' => value * 1000,
    'mi' => value * 1609.344,
    'kcal' => value,
    _ => null,
  };
}

double? storedExerciseLoad(ExerciseSetView exerciseSet) {
  if (isWeightUnit(exerciseSet.unit)) {
    return loadKg(exerciseSet.unit, exerciseSet.weight);
  }
  return exerciseSet.cardio ? null : exerciseSet.weight;
}

ExerciseSetView _toExerciseSetView(AppDatabase database, TypedResult row) {
  final set = row.readTable(database.exerciseSets);
  final exercise = row.readTable(database.exercises);
  final category = row.readTableOrNull(database.categories);
  final workout = row.readTableOrNull(database.workouts);
  return exerciseSetView(
    set,
    exercise,
    category: category?.name,
    planId: workout?.planId,
    strengthUnit:
        row.readTableOrNull(database.settings)?.strengthUnit ?? 'last-entry',
  );
}

ExerciseSetView exerciseSetView(
  ExerciseSet set,
  Exercise exercise, {
  String? category,
  int? planId,
  String strengthUnit = 'last-entry',
}) {
  final unit =
      exercise.kind == 'strength' &&
          isWeightUnit(exercise.displayUnit) &&
          strengthUnit != 'last-entry'
      ? strengthUnit
      : exercise.displayUnit;

  return ExerciseSetView(
    id: set.id,
    bodyWeight: set.bodyWeightKg == null
        ? 0
        : displayBodyWeight(unit, set.bodyWeightKg!),
    cardio: exercise.kind == 'cardio',
    category: category,
    created: set.timestamp.toLocal(),
    distance: displayDistance(unit, set.distanceMetres),
    duration: (set.durationMs ?? 0) / 60000,
    image: exercise.image,
    incline: set.incline?.round(),
    name: exercise.name,
    notes: set.notes,
    planId: planId,
    reps: set.reps ?? 0,
    restMs: exercise.defaultRestDurationMs,
    unit: unit,
    weight: displayLoad(unit, set.loadKg),
  );
}

JoinedSelectStatement<HasResultSet, dynamic> _exerciseSetQuery(
  AppDatabase database, {
  OrderingMode order = OrderingMode.desc,
  bool idsOnly = false,
}) {
  final sets = database.exerciseSets;
  final joins = [
    leftOuterJoin(database.settings, const Constant(true)),
    innerJoin(
      database.exercises,
      database.exercises.id.equalsExp(sets.exerciseId),
    ),
    leftOuterJoin(
      database.categories,
      database.categories.id.equalsExp(database.exercises.categoryId),
    ),
    if (!idsOnly)
      leftOuterJoin(
        database.workouts,
        database.workouts.id.equalsExp(sets.workoutId),
      ),
  ];
  final query = idsOnly
      ? database.selectOnly(sets).join(joins)
      : database.select(sets).join(joins);
  if (idsOnly) {
    query.addColumns([sets.id]);
  } else {
    query.orderBy([
      OrderingTerm(expression: sets.timestamp, mode: order),
      OrderingTerm(expression: sets.id, mode: order),
    ]);
  }
  return query;
}

class ExerciseSetQuery {
  const ExerciseSetQuery(
    this.database, {
    this.search = '',
    this.category,
    this.startDate,
    this.endDate,
    this.endDateExclusive,
    this.ids,
    this.cardio,
    this.exerciseName,
    this.exerciseId,
    this.workoutId,
    this.timestamp,
    this.repsGt,
    this.repsLt,
    this.weightGt,
    this.weightLt,
    this.limit,
    this.order = OrderingMode.desc,
  });

  final AppDatabase database;
  final String search;
  final String? category, exerciseName;
  final DateTime? startDate, endDate, endDateExclusive, timestamp;
  final Iterable<int>? ids;
  final bool? cardio;
  final int? exerciseId, workoutId, limit;
  final double? repsGt, repsLt, weightGt, weightLt;
  final OrderingMode order;

  JoinedSelectStatement<HasResultSet, dynamic> _query({bool idsOnly = false}) {
    final query = _exerciseSetQuery(database, idsOnly: idsOnly, order: order);
    final sets = database.exerciseSets;
    final exercises = database.exercises;
    for (final term
        in search.toLowerCase().split(' ').where((term) => term.isNotEmpty)) {
      query.where(exercises.name.lower().contains(term));
    }
    if (category != null)
      query.where(database.categories.name.equals(category!));
    if (startDate != null)
      query.where(sets.timestamp.isBiggerOrEqualValue(startDate!));
    if (endDate != null)
      query.where(sets.timestamp.isSmallerOrEqualValue(endDate!));
    if (endDateExclusive != null)
      query.where(sets.timestamp.isSmallerThanValue(endDateExclusive!));
    if (ids != null) query.where(sets.id.isIn(ids!));
    if (exerciseName != null) query.where(exercises.name.equals(exerciseName!));
    if (exerciseId != null) query.where(sets.exerciseId.equals(exerciseId!));
    if (workoutId != null) query.where(sets.workoutId.equals(workoutId!));
    if (timestamp != null) query.where(sets.timestamp.equals(timestamp!));
    if (cardio != null) {
      query.where(exercises.kind.equals(cardio! ? 'cardio' : 'strength'));
    }

    // History's numeric filters apply to strength sets only, in displayed units.
    final isCardio = exercises.kind.equals('cardio');
    final reps = ifNull(sets.reps, const Constant(0.0));
    final load = ifNull(sets.loadKg, const Constant(0.0));
    final preferredUnit = ifNull(
      database.settings.strengthUnit,
      const Constant('last-entry'),
    );
    final unit = exercises.kind.caseMatch<String>(
      when: {
        const Constant('strength'): preferredUnit.caseMatch<String>(
          when: {const Constant('last-entry'): exercises.displayUnit},
          orElse: preferredUnit,
        ),
      },
      orElse: exercises.displayUnit,
    );
    final weight = unit.caseMatch<double>(
      when: {
        const Constant('lb'): load / const Constant(0.45359237),
        const Constant('stone'): load / const Constant(6.35029318),
      },
      orElse: load,
    );
    if (repsGt != null) query.where(isCardio | reps.isBiggerThanValue(repsGt!));
    if (repsLt != null)
      query.where(isCardio | reps.isSmallerThanValue(repsLt!));
    if (weightGt != null)
      query.where(isCardio | weight.isBiggerThanValue(weightGt!));
    if (weightLt != null)
      query.where(isCardio | weight.isSmallerThanValue(weightLt!));
    if (!idsOnly && limit != null) query.limit(limit!);
    return query;
  }

  List<ExerciseSetView> _project(List<TypedResult> rows) => [
    for (final row in rows) _toExerciseSetView(database, row),
  ];

  Future<List<ExerciseSetView>> get() async => _project(await _query().get());

  Stream<List<ExerciseSetView>> watch() => _query().watch().map(_project);

  Future<ExerciseSetView?> firstOrNull() async {
    final row = await (_query()..limit(1)).getSingleOrNull();
    return row == null ? null : _toExerciseSetView(database, row);
  }

  Future<List<int>> getIds() async {
    final sets = database.exerciseSets;
    if (search.trim().isEmpty &&
        category == null &&
        exerciseName == null &&
        exerciseId == null &&
        workoutId == null &&
        timestamp == null &&
        endDateExclusive == null &&
        ids == null &&
        cardio == null &&
        repsGt == null &&
        repsLt == null &&
        weightGt == null &&
        weightLt == null) {
      final query = database.selectOnly(sets)..addColumns([sets.id]);
      if (startDate != null)
        query.where(sets.timestamp.isBiggerOrEqualValue(startDate!));
      if (endDate != null)
        query.where(sets.timestamp.isSmallerOrEqualValue(endDate!));
      return [for (final row in await query.get()) row.read(sets.id)!];
    }
    return [
      for (final row in await _query(idsOnly: true).get()) row.read(sets.id)!,
    ];
  }
}

Future<int> countExerciseSetsForExercises(
  AppDatabase database,
  Iterable<String> exerciseNames,
) async {
  final names = exerciseNames.toList();
  if (names.isEmpty) return 0;

  final count = database.exerciseSets.id.count();
  final row =
      await (database.selectOnly(database.exerciseSets)
            ..join([
              innerJoin(
                database.exercises,
                database.exercises.id.equalsExp(
                  database.exerciseSets.exerciseId,
                ),
              ),
            ])
            ..addColumns([count])
            ..where(database.exercises.name.isIn(names)))
          .getSingle();
  return row.read(count) ?? 0;
}

ExerciseSetsCompanion _setValues(
  ExerciseSetView set,
  int exerciseId,
  double? bodyWeightKg, {
  Value<int?> workoutId = const Value.absent(),
}) => ExerciseSetsCompanion(
  exerciseId: Value(exerciseId),
  workoutId: workoutId,
  timestamp: Value(set.created),
  reps: Value(set.reps),
  loadKg: Value(storedExerciseLoad(set)),
  durationMs: Value((set.duration * 60000).round()),
  distanceMetres: Value(distanceMetres(set.unit, set.distance)),
  incline: Value(set.incline?.toDouble()),
  bodyWeightKg: Value(bodyWeightKg),
  notes: Value(set.notes),
);

/// Inserts one exercise set into exercise_sets only.
Future<ExerciseSetView> insertExerciseSet(
  AppDatabase database, {
  required ExerciseSetView exerciseSet,
  required int exerciseId,
  int? workoutId,
  double? bodyWeightKg,
}) async {
  final storedWeightKg =
      bodyWeightKg ??
      (exerciseSet.bodyWeight == 0
          ? null
          : toKg(exerciseSet.unit, exerciseSet.bodyWeight)) ??
      (await getLatestBodyWeight(database))?.weightKg;

  final id = await database.exerciseSets.insertOne(
    _setValues(
      exerciseSet,
      exerciseId,
      storedWeightKg,
      workoutId: Value(workoutId),
    ),
  );
  return (await ExerciseSetQuery(database, ids: [id]).firstOrNull())!;
}

/// Updates per-performance data and exercise identity in exercise_sets only.
Future<void> updateExerciseSet(
  AppDatabase database, {
  required int id,
  required ExerciseSetView exerciseSet,
  required int exerciseId,
  double? bodyWeightKg,
}) {
  return (database.exerciseSets.update()..where((set) => set.id.equals(id)))
      .write(
        _setValues(
          exerciseSet,
          exerciseId,
          bodyWeightKg ??
              (exerciseSet.bodyWeight == 0
                  ? null
                  : toKg(exerciseSet.unit, exerciseSet.bodyWeight)),
        ),
      );
}

/// Deletes exercise sets by exercise_sets identifiers.
Future<int> deleteExerciseSets(AppDatabase database, Iterable<int> ids) {
  final values = ids.toList();
  if (values.isEmpty) return Future.value(0);
  return (database.exerciseSets.delete()..where((set) => set.id.isIn(values)))
      .go();
}

/// Compares a set against prior exercise sets for positive reinforcement.
Future<bool> isBestExerciseSet(
  AppDatabase database,
  ExerciseSetView exerciseSet,
) async {
  final exercise =
      await (database.exercises.select()
            ..where((row) => row.name.equals(exerciseSet.name))
            ..limit(1))
          .getSingleOrNull();
  if (exercise == null) return false;

  final previous = database.exerciseSets.select()
    ..where(
      (set) =>
          set.exerciseId.equals(exercise.id) &
          set.id.isNotValue(exerciseSet.id),
    );

  final weightedCardio = exerciseSet.cardio && isWeightUnit(exerciseSet.unit);

  if (exerciseSet.cardio && !weightedCardio) {
    if (exerciseSet.duration == 0) return false;
    final candidates = await previous.get();
    var bestPace = 0.0;
    var found = false;
    for (final candidate in candidates) {
      final duration = (candidate.durationMs ?? 0) / 60000;
      if (duration <= 0) continue;
      final pace =
          displayDistance(exerciseSet.unit, candidate.distanceMetres) /
          duration;
      if (!found || pace > bestPace) {
        bestPace = pace;
        found = true;
      }
    }
    return found && exerciseSet.distance / exerciseSet.duration > bestPace;
  }

  final best =
      await (previous
            ..orderBy([
              (set) =>
                  OrderingTerm.desc(ifNull(set.loadKg, const Constant(0.0))),
              (set) => weightedCardio
                  ? OrderingTerm.desc(ifNull(set.durationMs, const Constant(0)))
                  : OrderingTerm.desc(ifNull(set.reps, const Constant(0.0))),
            ])
            ..limit(1))
          .getSingleOrNull();
  if (best == null) return false;
  final bestWeight = displayLoad(exerciseSet.unit, best.loadKg);
  final bestSecondary = weightedCardio
      ? (best.durationMs ?? 0) / 60000
      : best.reps ?? 0;
  final secondary = weightedCardio ? exerciseSet.duration : exerciseSet.reps;
  return exerciseSet.weight > bestWeight ||
      (exerciseSet.weight == bestWeight && secondary > bestSecondary);
}
