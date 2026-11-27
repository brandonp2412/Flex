import 'package:drift/drift.dart';
import 'package:flex/database/database.dart';
import 'package:flex/main.dart';
import 'package:flex/plan/plan_count.dart';
import 'package:flex/plan/plan_exercise_draft.dart';
import 'package:flex/plan/workout_sessions.dart';

export 'package:flex/plan/plan_exercise_draft.dart';
export 'package:flex/plan/plan_count.dart';

List<Plan> filterPlans(
  List<Plan> plans,
  List<PlanExerciseEntry> exercises,
  String search,
  String Function(String) localizeDay,
) {
  final query = search.trim().toLowerCase();
  if (query.isEmpty) return plans;

  final terms = query.split(RegExp(r'\s+'));

  List<Plan> findMatches(bool flexible) {
    bool matches(String value) {
      final normalized = value.toLowerCase();
      return flexible
          ? terms.every(normalized.contains)
          : normalized.contains(query);
    }

    final matchingPlanIds = exercises
        .where(
          (entry) => entry.planExercise.enabled && matches(entry.exercise.name),
        )
        .map((entry) => entry.planExercise.planId)
        .toSet();

    return plans.where((plan) {
      if (matches(plan.title ?? '') ||
          matches(plan.days) ||
          matchingPlanIds.contains(plan.id)) {
        return true;
      }
      final localizedDays = plan.days
          .split(',')
          .where((day) => day.isNotEmpty)
          .map(localizeDay)
          .join(' ');
      return matches(localizedDays);
    }).toList();
  }

  final exact = findMatches(false);
  return exact.isNotEmpty || terms.length == 1 ? exact : findMatches(true);
}

List<PlanExerciseDraft> filterPlanExerciseDrafts(
  Iterable<PlanExerciseDraft> exercises,
  String search,
) {
  final query = search.toLowerCase();
  return [
    for (final exercise in exercises)
      if (exercise.nameLower.contains(query)) exercise,
  ];
}

typedef PlanOverview = ({Plan plan, PlanCount count});

Stream<List<PlanOverview>> watchPlanOverviews(AppDatabase db) {
  return db
      .customSelect(
        '''
          SELECT
            plans.*,
            COALESCE(
              (
                SELECT SUM(COALESCE(pe.max_sets, settings.max_sets))
                FROM plan_exercises AS pe
                CROSS JOIN settings
                WHERE pe.plan_id = plans.id
                  AND pe.enabled = 1
              ),
              0
            ) AS max_sets,
            COUNT(exercise_sets.id) AS session_count
          FROM plans
          LEFT JOIN workouts
            ON workouts.id = (
              SELECT active.id
              FROM workouts AS active
              WHERE active.plan_id = plans.id
                AND active.ended_at IS NULL
              ORDER BY active.started_at DESC, active.id DESC
              LIMIT 1
            )
          LEFT JOIN exercise_sets
            ON exercise_sets.workout_id = workouts.id
          GROUP BY plans.id
          ORDER BY plans.sequence
        ''',
        readsFrom: {
          db.plans,
          db.planExercises,
          db.settings,
          db.workouts,
          db.exerciseSets,
        },
      )
      .watch()
      .map(
        (rows) => rows
            .map(
              (row) => (
                plan: db.plans.map(row.data),
                count: PlanCount(
                  maxSets: row.read<int>('max_sets'),
                  planId: row.read<int>('id'),
                  total: row.read<int>('session_count'),
                ),
              ),
            )
            .toList(),
      );
}

Future<List<PlanExerciseDraft>> loadPlanExerciseDrafts(
  PlansCompanion plan,
) async {
  final query = db.exercises.selectOnly()
    ..addColumns([db.exercises.id, db.exercises.name])
    ..where(db.exercises.archived.equals(false))
    ..join([
      leftOuterJoin(
        db.planExercises,
        db.planExercises.planId.equals(plan.id.present ? plan.id.value : 0) &
            db.planExercises.exerciseId.equalsExp(db.exercises.id),
      ),
    ])
    ..addColumns(db.planExercises.$columns)
    ..orderBy([
      OrderingTerm.desc(
        ifNull(db.planExercises.enabled, const Constant(false)),
      ),
      OrderingTerm.asc(
        db.planExercises.enabled.caseMatch<int>(
          when: {const Constant(true): db.planExercises.sequence},
          orElse: const Constant(0),
        ),
      ),
      OrderingTerm.asc(db.exercises.id),
    ]);

  final rows = await query.get();
  final drafts = <PlanExerciseDraft>[];

  for (final row in rows) {
    final planExercise = PlanExercisesCompanion(
      planId: plan.id,
      id: Value.absentIfNull(row.read(db.planExercises.id)),
      exerciseId: Value(row.read(db.exercises.id)!),
      enabled: Value(row.read(db.planExercises.enabled) ?? false),
      maxSets: Value(row.read(db.planExercises.maxSets)),
      warmupSets: Value(row.read(db.planExercises.warmupSets)),
      timers: Value(row.read(db.planExercises.timers) ?? true),
      sequence: Value(row.read(db.planExercises.sequence) ?? 0),
    );
    final draft = PlanExerciseDraft(
      planExercise: planExercise,
      exerciseName: row.read(db.exercises.name)!,
    );
    drafts.add(draft);
  }

  return drafts;
}
