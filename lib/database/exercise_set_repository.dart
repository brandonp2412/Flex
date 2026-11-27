import 'package:drift/drift.dart';
import 'package:flex/constants.dart';
import 'package:flex/database/body_weight_repository.dart';
import 'package:flex/database/database.dart';
import 'package:flex/measurement_units.dart';

export 'package:flex/measurement_units.dart';

double? storedExerciseLoad(ExerciseSetView exerciseSet) {
  if (isWeightUnit(exerciseSet.unit)) {
    return loadKg(exerciseSet.unit, exerciseSet.weight);
  }
  return exerciseSet.cardio ? null : exerciseSet.weight;
}

ExerciseSetView exerciseSetView(AppDatabase database, TypedResult row) {
  final set = row.readTable(database.exerciseSets);
  final exercise = row.readTable(database.exercises);
  final strengthUnit =
      row.readTableOrNull(database.settings)?.strengthUnit ?? 'last-entry';
  final unit =
      exercise.kind == 'strength' &&
          isWeightUnit(exercise.displayUnit) &&
          strengthUnit != 'last-entry'
      ? strengthUnit
      : exercise.displayUnit;

  return ExerciseSetView(
    id: set.id,
    bodyWeight: displayLoad(unit, set.bodyWeightKg),
    cardio: exercise.kind == 'cardio',
    category: row.readTableOrNull(database.categories)?.name,
    created: set.timestamp.toLocal(),
    distance: displayDistance(unit, set.distanceMetres),
    duration: (set.durationMs ?? 0) / 60000,
    image: exercise.image,
    incline: set.incline,
    name: exercise.name,
    notes: set.notes,
    planId: row.readTableOrNull(database.workouts)?.planId,
    reps: set.reps ?? 0,
    restMs: exercise.defaultRestDurationMs,
    unit: unit,
    weight: displayLoad(unit, set.loadKg),
  );
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
    final sets = database.exerciseSets;
    final exercises = database.exercises;
    final terms = search
        .toLowerCase()
        .split(' ')
        .where((term) => term.isNotEmpty)
        .toList();
    final filterWeight = weightGt != null || weightLt != null;
    final filterReps = repsGt != null || repsLt != null;
    final joins = [
      if (!idsOnly || filterWeight)
        leftOuterJoin(database.settings, const Constant(true)),
      if (!idsOnly ||
          terms.isNotEmpty ||
          category != null ||
          exerciseName != null ||
          cardio != null ||
          filterWeight ||
          filterReps)
        innerJoin(exercises, exercises.id.equalsExp(sets.exerciseId)),
      if (!idsOnly || category != null)
        leftOuterJoin(
          database.categories,
          database.categories.id.equalsExp(exercises.categoryId),
        ),
      if (!idsOnly)
        leftOuterJoin(
          database.workouts,
          database.workouts.id.equalsExp(sets.workoutId),
        ),
    ];
    final query = idsOnly
        ? (database.selectOnly(sets)..addColumns([sets.id])).join(joins)
        : database.select(sets).join(joins);
    if (!idsOnly) {
      query.orderBy([
        OrderingTerm(expression: sets.timestamp, mode: order),
        OrderingTerm(expression: sets.id, mode: order),
      ]);
    }
    for (final term in terms) {
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
    if (filterReps) {
      final reps = ifNull(sets.reps, const Constant(0.0));
      if (repsGt != null)
        query.where(isCardio | reps.isBiggerThanValue(repsGt!));
      if (repsLt != null)
        query.where(isCardio | reps.isSmallerThanValue(repsLt!));
    }
    if (filterWeight) {
      final load = ifNull(sets.loadKg, const Constant(0.0));
      final preferredUnit = ifNull(
        database.settings.strengthUnit,
        const Constant('last-entry'),
      );
      final unit = CaseWhenExpression<String>(
        cases: [
          CaseWhen(
            exercises.kind.equals('strength') &
                exercises.displayUnit.isIn(weightUnitFactors.keys) &
                preferredUnit.isNotValue('last-entry'),
            then: preferredUnit,
          ),
        ],
        orElse: exercises.displayUnit,
      );
      final weight = unit.caseMatch<double>(
        when: {
          for (final entry in weightUnitFactors.entries)
            Constant(entry.key): load / Constant(entry.value),
        },
        orElse: load,
      );
      if (weightGt != null)
        query.where(isCardio | weight.isBiggerThanValue(weightGt!));
      if (weightLt != null)
        query.where(isCardio | weight.isSmallerThanValue(weightLt!));
    }
    if (!idsOnly && limit != null) query.limit(limit!);
    return query;
  }

  Selectable<ExerciseSetView> _views({bool first = false}) {
    final query = _query();
    if (first) query.limit(1);
    return query.map((row) => exerciseSetView(database, row));
  }

  Future<List<ExerciseSetView>> get() => _views().get();
  Stream<List<ExerciseSetView>> watch() => _views().watch();
  Future<ExerciseSetView?> firstOrNull() =>
      _views(first: true).getSingleOrNull();
  Future<List<int>> getIds() => _query(
    idsOnly: true,
  ).map((row) => row.read(database.exerciseSets.id)!).get();
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
  incline: Value(set.incline),
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
          : loadKg(exerciseSet.unit, exerciseSet.bodyWeight)) ??
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
                  : loadKg(exerciseSet.unit, exerciseSet.bodyWeight)),
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
  final ids = database.exercises.selectOnly()
    ..addColumns([database.exercises.id])
    ..where(database.exercises.name.equals(exerciseSet.name));
  final previous = database.exerciseSets.select()
    ..where(
      (set) =>
          set.exerciseId.isInQuery(ids) & set.id.isNotValue(exerciseSet.id),
    );

  final weightedCardio = exerciseSet.cardio && isWeightUnit(exerciseSet.unit);

  if (exerciseSet.cardio && !weightedCardio) {
    if (exerciseSet.duration == 0) return false;
    final best =
        await (previous
              ..where((set) => set.durationMs.isBiggerThanValue(0))
              ..orderBy([
                (set) => OrderingTerm.desc(
                  ifNull(set.distanceMetres, const Constant(0.0)) /
                      set.durationMs.cast<double>(),
                ),
              ])
              ..limit(1))
            .getSingleOrNull();
    return best != null &&
        exerciseSet.distance / exerciseSet.duration >
            displayDistance(exerciseSet.unit, best.distanceMetres) /
                (best.durationMs! / 60000);
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
