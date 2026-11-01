import 'package:drift/drift.dart';
import 'package:flex/database/database.dart';
import 'package:flex/database/exercise_catalog.dart';
import 'package:flex/main.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mock_tests.dart';

void main() {
  setUp(() => db = testDb());

  test(
    'merge keeps every set and reconciles overlapping plan exercises',
    () async {
      final keep = await createExerciseDefinition(
        db,
        name: 'Incline press X',
        cardio: false,
        displayUnit: 'kg',
        category: 'Chest',
        image: '/tmp/incline.png',
      );
      final source = await createExerciseDefinition(
        db,
        name: 'Incline bench press X',
        cardio: false,
        displayUnit: 'lb',
      );
      final planId = await db.plans.insertOne(
        PlansCompanion.insert(days: 'Monday'),
      );
      await db.planExercises.insertOne(
        PlanExercisesCompanion.insert(
          planId: planId,
          exerciseId: keep.id,
          enabled: false,
          maxSets: const Value(2),
          sequence: const Value(5),
        ),
      );
      await db.planExercises.insertOne(
        PlanExercisesCompanion.insert(
          planId: planId,
          exerciseId: source.id,
          enabled: true,
          maxSets: const Value(4),
          sequence: const Value(1),
        ),
      );
      final firstTime = DateTime(2026, 10, 2, 9);
      final secondTime = DateTime(2026, 10, 3, 9);
      final firstId = await db.exerciseSets.insertOne(
        ExerciseSetsCompanion.insert(
          exerciseId: keep.id,
          timestamp: firstTime,
          reps: const Value(8),
          loadKg: const Value(60),
        ),
      );
      final secondId = await db.exerciseSets.insertOne(
        ExerciseSetsCompanion.insert(
          exerciseId: source.id,
          timestamp: secondTime,
          reps: const Value(10),
          loadKg: const Value(70),
        ),
      );

      await mergeExerciseGraphs(
        db,
        exerciseIds: {source.id, keep.id},
        keepExerciseId: keep.id,
        name: keep.name,
      );

      final exercises = await db.exercises.select().get();
      final kept = exercises.singleWhere((row) => row.id == keep.id);
      expect(exercises.any((row) => row.id == source.id), isFalse);
      expect(kept.image, '/tmp/incline.png');
      expect(kept.displayUnit, 'kg');
      final sets = await db.exerciseSets.select().get();
      expect(sets.map((set) => set.id), containsAll([firstId, secondId]));
      expect(
        sets.map((set) => set.timestamp),
        containsAll([firstTime, secondTime]),
      );
      expect(sets.every((set) => set.exerciseId == keep.id), isTrue);
      final planRows =
          await (db.planExercises.select()
                ..where((row) => row.planId.equals(planId)))
              .get();
      expect(planRows, hasLength(1));
      expect(planRows.single.exerciseId, keep.id);
      expect(planRows.single.enabled, isTrue);
      expect(planRows.single.maxSets, 4);
      expect(planRows.single.sequence, 1);
    },
  );

  test('new name retains chosen graph identity and all history', () async {
    final first = await createExerciseDefinition(
      db,
      name: 'Row old',
      cardio: false,
      displayUnit: 'kg',
    );
    final second = await createExerciseDefinition(
      db,
      name: 'Row older',
      cardio: false,
      displayUnit: 'kg',
    );
    await db.exerciseSets.insertOne(
      ExerciseSetsCompanion.insert(
        exerciseId: second.id,
        timestamp: DateTime(2026, 10, 4),
      ),
    );

    await mergeExerciseGraphs(
      db,
      exerciseIds: {first.id, second.id},
      keepExerciseId: first.id,
      name: 'Cable row',
    );

    final exercises = await db.exercises.select().get();
    expect(
      exercises.singleWhere((row) => row.id == first.id).name,
      'Cable row',
    );
    expect(exercises.any((row) => row.id == second.id), isFalse);
    expect((await db.exerciseSets.select().get()).single.exerciseId, first.id);
  });

  test('name collision rolls back the entire merge', () async {
    final first = await createExerciseDefinition(
      db,
      name: 'First',
      cardio: false,
      displayUnit: 'kg',
    );
    final second = await createExerciseDefinition(
      db,
      name: 'Second',
      cardio: false,
      displayUnit: 'kg',
    );
    await createExerciseDefinition(
      db,
      name: 'Taken',
      cardio: false,
      displayUnit: 'kg',
    );
    await db.exerciseSets.insertOne(
      ExerciseSetsCompanion.insert(
        exerciseId: second.id,
        timestamp: DateTime(2026, 10, 4),
      ),
    );

    await expectLater(
      mergeExerciseGraphs(
        db,
        exerciseIds: {first.id, second.id},
        keepExerciseId: first.id,
        name: 'Taken',
      ),
      throwsStateError,
    );
    final exercises = await db.exercises.select().get();
    expect(
      exercises.where((row) => ['First', 'Second', 'Taken'].contains(row.name)),
      hasLength(3),
    );
    expect((await db.exerciseSets.select().get()).single.exerciseId, second.id);
  });

  test('cannot merge incompatible cardio types', () async {
    final strength = await createExerciseDefinition(
      db,
      name: 'Squat X',
      cardio: false,
      displayUnit: 'kg',
    );
    final cardio = await createExerciseDefinition(
      db,
      name: 'Run X',
      cardio: true,
      displayUnit: 'km',
    );
    await expectLater(
      mergeExerciseGraphs(
        db,
        exerciseIds: {strength.id, cardio.id},
        keepExerciseId: strength.id,
        name: strength.name,
      ),
      throwsStateError,
    );
    final exercises = await db.exercises.select().get();
    expect(exercises.any((row) => row.id == strength.id), isTrue);
    expect(exercises.any((row) => row.id == cardio.id), isTrue);
  });
}
