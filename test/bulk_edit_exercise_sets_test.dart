import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flex/database/bulk_edit_exercise_sets.dart';
import 'package:flex/database/database.dart';
import 'package:flex/database/exercise_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test(
    'updates 6788 sets without changing untouched values or definitions',
    () async {
      final lift = await createExerciseDefinition(
        database,
        name: 'Bulk lift',
        cardio: false,
        displayUnit: 'lb',
        category: 'Bulk category',
        notes: 'exercise notes',
      );
      final run = await createExerciseDefinition(
        database,
        name: 'Bulk run',
        cardio: true,
        displayUnit: 'km',
      );
      final timestamp = DateTime(2026, 11, 1);
      final workout = await database.workouts.insertOne(
        WorkoutsCompanion.insert(startedAt: timestamp),
      );
      await database.batch((batch) {
        batch.insertAll(database.exerciseSets, [
          for (var i = 0; i < 6788; i++)
            ExerciseSetsCompanion.insert(
              exerciseId: i.isEven ? lift.id : run.id,
              workoutId: Value(workout),
              timestamp: timestamp,
              reps: const Value(5),
              loadKg: i.isEven ? const Value(40) : const Value(null),
              distanceMetres: i.isEven ? const Value(null) : const Value(5000),
              durationMs: const Value(60000),
              notes: const Value('keep'),
            ),
        ]);
      });
      final original = await database.exerciseSets.select().get();
      final excluded = original.last;
      final timer = Stopwatch()..start();
      await bulkEditExerciseSets(
        database,
        original.take(6787).map((row) => row.id),
        reps: 10,
      );
      timer.stop();
      final updated = await database.exerciseSets.select().get();
      expect(updated, hasLength(6788));
      for (var i = 0; i < original.length; i++) {
        expect(
          updated[i],
          original[i].id == excluded.id
              ? original[i]
              : original[i].copyWith(reps: const Value(10)),
        );
      }
      expect(await getExerciseByName(database, lift.name), lift);
      expect(await getExerciseByName(database, run.name), run);
      // A generous ceiling catches accidental reintroduction of per-row writes.
      expect(timer.elapsed, lessThan(const Duration(seconds: 5)));
    },
  );

  test(
    'converts entered weights by displayed unit and keeps existing metadata',
    () async {
      final kg = await createExerciseDefinition(
        database,
        name: 'Bulk kg',
        cardio: false,
        displayUnit: 'kg',
      );
      final lb = await createExerciseDefinition(
        database,
        name: 'Bulk lb',
        cardio: false,
        displayUnit: 'lb',
      );
      final ids = [
        for (final e in [kg, lb])
          await database.exerciseSets.insertOne(
            ExerciseSetsCompanion.insert(
              exerciseId: e.id,
              timestamp: DateTime(2026, 11, 1),
            ),
          ),
      ];
      await bulkEditExerciseSets(database, ids, weight: 100);
      final rows = await database.exerciseSets.select().get();
      expect(rows.singleWhere((e) => e.exerciseId == kg.id).loadKg, 100);
      expect(
        rows.singleWhere((e) => e.exerciseId == lb.id).loadKg,
        closeTo(45.359237, 1e-8),
      );
      await bulkEditExerciseSets(database, [ids.first], name: lb.name, reps: 8);
      final moved =
          await (database.exerciseSets.select()
                ..where((e) => e.id.equals(ids.first)))
              .getSingle();
      expect(moved.exerciseId, lb.id);
      expect(moved.loadKg, 100);
      expect(moved.reps, 8);
      expect(await getExerciseByName(database, lb.name), lb);
    },
  );

  test('rolls back metrics if an exercise metadata update fails', () async {
    final e = await createExerciseDefinition(
      database,
      name: 'Rollback lift',
      cardio: false,
      displayUnit: 'kg',
    );
    final id = await database.exerciseSets.insertOne(
      ExerciseSetsCompanion.insert(
        exerciseId: e.id,
        timestamp: DateTime(2026, 11, 1),
        reps: const Value(5),
      ),
    );
    await database.customStatement(
      "CREATE TRIGGER reject_bulk_kind BEFORE UPDATE OF kind ON exercises BEGIN SELECT RAISE(ABORT, 'test failure'); END",
    );
    await expectLater(
      bulkEditExerciseSets(database, [id], reps: 10, cardio: true),
      throwsA(anything),
    );
    expect((await database.exerciseSets.select().getSingle()).reps, 5);
    expect(await getExerciseByName(database, e.name), e);
  });
}
