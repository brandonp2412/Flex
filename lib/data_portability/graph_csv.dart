import 'package:flex/database/exercise_catalog.dart';
import 'package:flex/database/categories.dart';
import 'package:csv/csv.dart';
import 'package:drift/drift.dart';
import 'package:flex/data_portability/graph_csv_import_exception.dart';
import 'package:flex/data_portability/graph_csv_import_result.dart';
import 'package:flex/data_portability/graph_csv_row.dart';
import 'package:flex/database/database.dart';
import 'package:flex/database/exercise_set_repository.dart';

export 'package:flex/data_portability/graph_csv_import_exception.dart';
export 'package:flex/data_portability/graph_csv_import_result.dart';

const _format = 'flex_graphs_v2';
const _previousFormat = 'flexify_graphs_v2';

const _header = <String>[
  'format',
  'recordType',
  'id',
  'exerciseId',
  'workoutId',
  'name',
  'kind',
  'displayUnit',
  'category',
  'image',
  'defaultRestDurationMs',
  'notes',
  'graphMetric',
  'graphPeriod',
  'graphLimit',
  'graphTimeBasedXAxis',
  'archived',
  'timestamp',
  'reps',
  'loadKg',
  'durationMs',
  'distanceMetres',
  'incline',
  'bodyWeightKg',
  'photo',
  'planId',
  'startedAt',
  'endedAt',
];

Future<String> exportGraphCsv(AppDatabase database) async {
  final exercises = await database.exercises.select().get();
  final categories = {
    for (final category in await database.categories.select().get())
      category.id: category.name,
  };
  final workouts = await database.workouts.select().get();
  final exerciseSets = await database.exerciseSets.select().get();
  final bodyWeights = await database.bodyWeights.select().get();

  final rows = <List<Object?>>[_header];
  void add(String type, Map<String, Object?> fields) => rows.add([
    _format,
    type,
    for (final column in _header.skip(2)) fields[column],
  ]);

  for (final exercise in exercises) {
    add('exercise', {
      'id': exercise.id,
      'name': exercise.name,
      'kind': exercise.kind,
      'displayUnit': exercise.displayUnit,
      'category': categories[exercise.categoryId],
      'image': exercise.image,
      'defaultRestDurationMs': exercise.defaultRestDurationMs,
      'notes': exercise.notes,
      'graphMetric': exercise.graphMetric,
      'graphPeriod': exercise.graphPeriod,
      'graphLimit': exercise.graphLimit,
      'graphTimeBasedXAxis': exercise.graphTimeBasedXAxis,
      'archived': exercise.archived,
    });
  }
  for (final workout in workouts) {
    add('workout', {
      'id': workout.id,
      'planId': workout.planId,
      'startedAt': workout.startedAt.toIso8601String(),
      'endedAt': workout.endedAt?.toIso8601String(),
    });
  }
  for (final set in exerciseSets) {
    add('exerciseSet', {
      'id': set.id,
      'exerciseId': set.exerciseId,
      'workoutId': set.workoutId,
      'notes': set.notes,
      'timestamp': set.timestamp.toIso8601String(),
      'reps': set.reps,
      'loadKg': set.loadKg,
      'durationMs': set.durationMs,
      'distanceMetres': set.distanceMetres,
      'incline': set.incline,
      'bodyWeightKg': set.bodyWeightKg,
    });
  }
  for (final weight in bodyWeights) {
    add('bodyWeight', {
      'id': weight.id,
      'timestamp': weight.timestamp.toIso8601String(),
      'bodyWeightKg': weight.weightKg,
      'photo': weight.photo,
    });
  }

  return CsvEncoder(lineDelimiter: "\n").convert(rows);
}

Future<GraphCsvImportResult> importGraphCsv(
  AppDatabase database,
  String csvContent,
) async {
  final rows = CsvDecoder().convert(csvContent);
  if (rows.isEmpty) {
    throw const GraphCsvImportException('CSV file is empty.');
  }
  if (rows.length <= 1) {
    throw const GraphCsvImportException('CSV needs at least one data row.');
  }

  final header = rows.first.map((value) => value.toString()).toList();
  if (header.contains('recordType') && header.contains('format')) {
    return _importV2(database, header, rows.skip(1).toList());
  }
  return _importLegacy(database, header, rows.skip(1).toList());
}

Future<GraphCsvImportResult> _importV2(
  AppDatabase database,
  List<String> header,
  List<List<dynamic>> rows,
) async {
  final records = rows.map((row) => GraphCsvRow(header, row)).toList();
  for (final row in records) {
    final format = row.string('format');
    if (format != _format && format != _previousFormat) {
      throw GraphCsvImportException('Unsupported graph CSV format: $format.');
    }
  }

  final exerciseIds = <int, int>{};
  final workoutIds = <int, int>{};
  var exerciseCount = 0;
  var workoutCount = 0;
  var setCount = 0;
  var bodyWeightCount = 0;

  await _replaceHistory(database, () async {
    for (final row in records.where(
      (row) => row.string('recordType') == 'exercise',
    )) {
      final sourceId = row.integer('id', required: true)!;
      final name = row.string('name', required: true);
      final categoryId = await ensureCategoryId(
        database,
        row.nullableString('category'),
      );
      final companion = ExercisesCompanion(
        name: Value(name),
        kind: Value(row.string('kind', required: true)),
        displayUnit: Value(row.string('displayUnit', required: true)),
        categoryId: Value(categoryId),
        image: Value(row.nullableString('image')),
        defaultRestDurationMs: Value(row.integer('defaultRestDurationMs')),
        notes: Value(row.nullableString('notes')),
        graphMetric: Value(row.string('graphMetric', fallback: 'bestWeight')),
        graphPeriod: Value(row.string('graphPeriod', fallback: 'day')),
        graphLimit: Value(row.integer('graphLimit') ?? 20),
        graphTimeBasedXAxis: Value(row.boolean('graphTimeBasedXAxis')),
        archived: Value(row.boolean('archived')),
      );

      exerciseIds[sourceId] = (await upsertExerciseDefinition(
        database,
        companion,
      )).id;
      exerciseCount++;
    }

    final existingPlanIds = {
      for (final plan in await database.plans.select().get()) plan.id,
    };
    for (final row in records.where(
      (row) => row.string('recordType') == 'workout',
    )) {
      final sourceId = row.integer('id', required: true)!;
      final sourcePlanId = row.integer('planId');
      final targetId = await database.workouts.insertOne(
        WorkoutsCompanion.insert(
          planId: Value(
            sourcePlanId != null && existingPlanIds.contains(sourcePlanId)
                ? sourcePlanId
                : null,
          ),
          startedAt: row.date('startedAt', required: true)!,
          endedAt: Value(row.date('endedAt')),
        ),
      );
      workoutIds[sourceId] = targetId;
      workoutCount++;
    }

    for (final row in records.where(
      (row) => row.string('recordType') == 'bodyWeight',
    )) {
      await database.bodyWeights.insertOne(
        BodyWeightsCompanion.insert(
          timestamp: row.date('timestamp', required: true)!,
          weightKg: row.number('bodyWeightKg', required: true)!,
          photo: Value(row.nullableString('photo')),
        ),
      );
      bodyWeightCount++;
    }

    for (final row in records.where(
      (row) => row.string('recordType') == 'exerciseSet',
    )) {
      final sourceId = row.integer('exerciseId', required: true)!;
      final exerciseId = exerciseIds[sourceId];
      if (exerciseId == null) {
        throw GraphCsvImportException(
          'Exercise set references missing exercise $sourceId.',
        );
      }
      final sourceWorkoutId = row.integer('workoutId');
      final workoutId = sourceWorkoutId == null
          ? null
          : workoutIds[sourceWorkoutId];
      if (sourceWorkoutId != null && workoutId == null) {
        throw GraphCsvImportException(
          'Exercise set references missing workout $sourceWorkoutId.',
        );
      }

      await database.exerciseSets.insertOne(
        ExerciseSetsCompanion.insert(
          exerciseId: exerciseId,
          workoutId: Value(workoutId),
          timestamp: row.date('timestamp', required: true)!,
          reps: Value(row.number('reps')),
          loadKg: Value(row.number('loadKg')),
          durationMs: Value(row.integer('durationMs')),
          distanceMetres: Value(row.number('distanceMetres')),
          incline: Value(row.number('incline')),
          bodyWeightKg: Value(row.number('bodyWeightKg')),
          notes: Value(row.nullableString('notes')),
        ),
      );
      setCount++;
    }
  });

  return GraphCsvImportResult(
    exercises: exerciseCount,
    workouts: workoutCount,
    exerciseSets: setCount,
    bodyWeights: bodyWeightCount,
  );
}

Future<GraphCsvImportResult> _importLegacy(
  AppDatabase database,
  List<String> header,
  List<List<dynamic>> rows,
) async {
  if (!header.contains('name') ||
      !header.contains('created') ||
      !header.contains('unit')) {
    throw const GraphCsvImportException('Unrecognized graph CSV columns.');
  }

  final records = rows.map((row) => GraphCsvRow(header, row)).toList();
  final legacyWeights =
      records
          .where(
            (row) => row.string('name') == 'Weight' && !row.boolean('hidden'),
          )
          .map(
            (row) => (
              timestamp: row.date('created', required: true)!,
              unit: row.string('unit', fallback: 'kg'),
              value: row.number('weight', required: true)!,
            ),
          )
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

  final weightUnit = legacyWeights.isEmpty ? null : legacyWeights.last.unit;
  final exerciseIds = <String, int>{};
  var setCount = 0;
  var bodyWeightCount = 0;

  await _replaceHistory(database, () async {
    for (final weight in legacyWeights) {
      final kg = loadKg(weight.unit, weight.value);
      if (kg == null) continue;
      await database.bodyWeights.insertOne(
        BodyWeightsCompanion.insert(timestamp: weight.timestamp, weightKg: kg),
      );
      bodyWeightCount++;
    }

    final realRows = records.where((row) => row.string('name') != 'Weight');
    for (final row in realRows) {
      final name = row.string('name', required: true);
      if (exerciseIds.containsKey(name)) continue;

      final kind = row.boolean('cardio') ? 'cardio' : 'strength';
      final unit = row.string('unit', fallback: kind == 'cardio' ? 'km' : 'kg');
      exerciseIds[name] = (await upsertExerciseDefinition(
        database,
        ExercisesCompanion.insert(name: name, kind: kind, displayUnit: unit),
      )).id;
    }

    for (final row in realRows.where((row) => !row.boolean('hidden'))) {
      final timestamp = row.date('created', required: true)!;
      final unit = row.string('unit', fallback: 'kg');
      final rawBodyWeight = row.number('bodyWeight') ?? 0;
      final bodyWeightUnit = _legacyBodyWeightUnit(
        legacyWeights,
        timestamp,
        weightUnit,
      );
      final bodyWeightKg = rawBodyWeight == 0 || bodyWeightUnit == null
          ? null
          : loadKg(bodyWeightUnit, rawBodyWeight);

      await database.exerciseSets.insertOne(
        ExerciseSetsCompanion.insert(
          exerciseId: exerciseIds[row.string('name', required: true)]!,
          timestamp: timestamp,
          reps: Value(row.number('reps')),
          loadKg: Value(loadKg(unit, row.number('weight') ?? 0)),
          durationMs: Value(
            row.has('duration')
                ? ((row.number('duration') ?? 0) * 60000).round()
                : null,
          ),
          distanceMetres: Value(
            row.has('distance')
                ? distanceMetres(unit, row.number('distance') ?? 0)
                : null,
          ),
          incline: Value(row.number('incline')),
          bodyWeightKg: Value(bodyWeightKg),
        ),
      );
      setCount++;
    }
  });

  return GraphCsvImportResult(
    exercises: exerciseIds.length,
    workouts: 0,
    exerciseSets: setCount,
    bodyWeights: bodyWeightCount,
  );
}

String? _legacyBodyWeightUnit(
  List<({DateTime timestamp, String unit, double value})> weights,
  DateTime timestamp,
  String? fallback,
) {
  String? result;
  for (final weight in weights) {
    if (weight.timestamp.isAfter(timestamp)) break;
    result = weight.unit;
  }
  return result ?? fallback;
}

Future<void> _replaceHistory(
  AppDatabase database,
  Future<void> Function() restore,
) => database.transaction(() async {
  await database.exerciseSets.deleteAll();
  await database.workouts.deleteAll();
  await database.bodyWeights.deleteAll();
  await restore();
});
