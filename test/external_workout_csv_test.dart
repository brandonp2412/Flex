import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flex/data_portability/external_workout_csv.dart';
import 'package:flex/database/database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    await database.exerciseSets.deleteAll();
    await database.workouts.deleteAll();
    await database.planExercises.deleteAll();
    await database.exercises.deleteAll();
  });
  tearDown(() async => database.close());

  test('openGym CSV imports sets, durations and lb conversion', () async {
    const csv =
        '\uFEFFdate,start_time,end_time,workout,workout_note,exercise,exercise_id,body_part,superset_id,set,set_type,side,weight,unit,reps,rpe,rir,distance_km,seconds,incline,note,set_note\r\n'
        '2026-10-06,2026-10-06 06:00,,Push,,Bench Press,bench,chest,,1,normal,,220.462262,lb,5,,,,,,,Paused\r\n'
        '2026-10-06,2026-10-06 06:00,,Push,,Bench Press,bench,chest,,2,normal,,220.462262,lb,5,,,,,,,\r\n'
        '2026-10-06,2026-10-06 06:00,,Push,,Treadmill,run,cardio,,1,normal,,,kg,,,,5,1500,3,,\r\n';
    final first = await importExternalWorkoutCsv(database, csv);
    expect(first.format, ExternalWorkoutFormat.openGym);
    expect(first.workouts, 1);
    expect(first.exercises, 2);
    expect(first.sets, 3);

    final sets = await database.exerciseSets.select().get();
    expect(sets.where((set) => set.loadKg != null).length, 2);
    expect(sets.first.loadKg, closeTo(100, 0.001));
    expect(sets.last.distanceMetres, 5000);
    expect(sets.last.durationMs, 1500000);

    final again = await importExternalWorkoutCsv(database, csv);
    expect(again.workouts, 0);
    expect(again.exercises, 0);
    expect(again.sets, 0);
    expect((await database.exerciseSets.select().get()).length, 3);
  });

  test('LiftLog CSV uses sessions and keeps existing Flex data', () async {
    final existingExercise = await database.exercises.insertOne(
      ExercisesCompanion.insert(
        name: 'Deadlift',
        kind: 'strength',
        displayUnit: 'kg',
      ),
    );
    await database.exerciseSets.insertOne(
      ExerciseSetsCompanion.insert(
        exerciseId: existingExercise,
        timestamp: DateTime(2020, 1, 1),
      ),
    );
    const csv =
        'SessionId,Timestamp,Exercise,Weight,WeightUnit,Reps,TargetReps,Notes\n'
        '395b0272,2026-10-06T12:34:32.245+11:00,Squat,102.5,kg,5,5,\n'
        '395b0272,2026-10-06T12:36:52.225+11:00,Squat,102.5,kg,5,5,\n'
        'another,2026-10-07T09:00:00+11:00,Deadlift,220,lb,3,5,Top set\n';
    final result = await importExternalWorkoutCsv(database, csv);
    expect(result.format, ExternalWorkoutFormat.liftLog);
    expect(result.workouts, 2);
    expect(result.exercises, 1);
    expect(result.sets, 3);
    expect((await database.exerciseSets.select().get()).length, 4);
    expect((await database.exercises.select().get()).length, 2);
    final last = (await database.exerciseSets.select().get()).last;
    expect(last.loadKg, closeTo(99.79032, 0.001));
    expect(last.notes, 'Top set');
  });

  test('Fast N Fitness Records export expands set counts', () async {
    const csv =
        'TABLE,DATE,TIME,EXERCISE,EXERCISE_TYPE,SETS,REPS,WEIGHT,WEIGHT_UNIT,SECONDS,DISTANCE,DISTANCE_UNIT,DURATION,NOTES,RECORD_TYPE,PROGRAM_NAME\n'
        'RECORD,2026-10-06,08:30:00,Squat,strength,3,5,100,kg,0,0,km,0,,FREE_RECORD,\n'
        'RECORD,2026-10-06,08:35:00,Bike,cardio,1,0,0,kg,1800,10,km,0,,FREE_RECORD,\n'
        'TEMPLATE,2026-10-06,08:30:00,Ignore,strength,1,5,1,kg,0,0,km,0,,,\n';
    final result = await importExternalWorkoutCsv(database, csv);
    expect(result.format, ExternalWorkoutFormat.fastNFitness);
    expect(result.workouts, 1);
    expect(result.exercises, 2);
    expect(result.sets, 4);
    final sets = await database.exerciseSets.select().get();
    expect(sets.where((set) => set.reps == 5).length, 3);
    expect(sets.last.durationMs, 1800000);
    expect(sets.last.distanceMetres, 10000);
    final again = await importExternalWorkoutCsv(database, csv);
    expect(again.sets, 0);
  });

  test('invalid CSV is rejected atomically', () async {
    const csv =
        'SessionId,Timestamp,Exercise,Weight,WeightUnit,Reps,TargetReps,Notes\n'
        'a,2026-10-06T12:34:32,Squat,100,kg,5,5,\n'
        'a,2026-10-06T12:35:00,Squat,100,parsecs,5,5,\n';
    await expectLater(
      importExternalWorkoutCsv(database, csv),
      throwsA(isA<ExternalWorkoutImportException>()),
    );
    expect(await database.exerciseSets.select().get(), isEmpty);
    expect(await database.workouts.select().get(), isEmpty);
  });

  test('rejects unsupported schema without changing anything', () async {
    expect(
      () => detectExternalWorkoutFormat('name,whatever\nSquat,5'),
      throwsA(isA<ExternalWorkoutImportException>()),
    );
    expect(await database.exercises.select().get(), isEmpty);
  });
}
