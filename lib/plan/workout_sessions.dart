import 'package:drift/drift.dart';
import 'package:flex/database/database.dart';

class PlanExerciseEntry {
  final PlanExercise planExercise;
  final Exercise exercise;

  const PlanExerciseEntry({required this.planExercise, required this.exercise});
}

Map<int, List<PlanExerciseEntry>> groupEnabledPlanExercisesByPlan(
  Iterable<PlanExerciseEntry> entries,
) {
  final grouped = <int, List<PlanExerciseEntry>>{};
  for (final entry in entries) {
    if (!entry.planExercise.enabled) continue;
    grouped
        .putIfAbsent(entry.planExercise.planId, () => <PlanExerciseEntry>[])
        .add(entry);
  }
  return grouped;
}

Stream<List<PlanExerciseEntry>> watchPlanExerciseEntries(
  AppDatabase database,
  int planId,
) => watchAllPlanExerciseEntries(database, planId: planId);

Stream<List<PlanExerciseEntry>> watchAllPlanExerciseEntries(
  AppDatabase database, {
  int? planId,
}) => _planExerciseEntries(database, planId: planId).watch();

Selectable<PlanExerciseEntry> _planExerciseEntries(
  AppDatabase database, {
  int? planId,
}) {
  final query = database.select(database.planExercises).join([
    innerJoin(
      database.exercises,
      database.exercises.id.equalsExp(database.planExercises.exerciseId),
    ),
  ]);
  if (planId != null) {
    query.where(
      database.planExercises.planId.equals(planId) &
          database.planExercises.enabled.equals(true),
    );
  }
  query.orderBy([
    OrderingTerm.asc(database.planExercises.planId),
    OrderingTerm.asc(database.planExercises.sequence),
    OrderingTerm.asc(database.planExercises.id),
  ]);
  return query.map(
    (row) => PlanExerciseEntry(
      planExercise: row.readTable(database.planExercises),
      exercise: row.readTable(database.exercises),
    ),
  );
}

Future<List<PlanExerciseEntry>> getAllPlanExerciseEntries(
  AppDatabase database,
) => _planExerciseEntries(database).get();

Future<Workout> resumeOrStartWorkout(
  AppDatabase database,
  int planId, {
  DateTime? now,
}) {
  return database.transaction(() async {
    final existing =
        await (database.workouts.select()
              ..where(
                (workout) =>
                    workout.planId.equals(planId) & workout.endedAt.isNull(),
              )
              ..orderBy([
                (workout) => OrderingTerm.desc(workout.startedAt),
                (workout) => OrderingTerm.desc(workout.id),
              ])
              ..limit(1))
            .getSingleOrNull();
    final currentTime = now ?? DateTime.now();
    if (existing != null) {
      if (currentTime.difference(existing.startedAt) <
          const Duration(hours: 18)) {
        return existing;
      }
      await finishWorkout(database, existing.id, now: currentTime);
    }

    return database.workouts.insertReturning(
      WorkoutsCompanion.insert(
        planId: Value(planId),
        startedAt: now ?? DateTime.now(),
      ),
    );
  });
}

Future<void> finishWorkout(
  AppDatabase database,
  int workoutId, {
  DateTime? now,
}) async {
  await (database.workouts.update()..where(
        (workout) => workout.id.equals(workoutId) & workout.endedAt.isNull(),
      ))
      .write(WorkoutsCompanion(endedAt: Value(now ?? DateTime.now())));
}
