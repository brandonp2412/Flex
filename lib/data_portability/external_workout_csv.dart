import 'package:flex/measurement_units.dart';
import 'package:csv/csv.dart';
import 'package:drift/drift.dart';
import 'package:flex/data_portability/csv_record.dart';
import 'package:flex/data_portability/external_workout_format.dart';
import 'package:flex/data_portability/external_workout_import_exception.dart';
import 'package:flex/data_portability/external_workout_import_result.dart';
import 'package:flex/data_portability/imported_set.dart';
import 'package:flex/database/database.dart';

export 'package:flex/data_portability/external_workout_format.dart';
export 'package:flex/data_portability/external_workout_import_exception.dart';
export 'package:flex/data_portability/external_workout_import_result.dart';

String? _note(String a, String b) {
  final parts = [a, b].where((part) => part.isNotEmpty).toSet();
  return parts.isEmpty ? null : parts.join(' · ');
}

String _weightUnit(String unit) => switch (unit.toLowerCase()) {
  'kg' || 'kgs' || '' => 'kg',
  'lb' || 'lbs' => 'lb',
  'st' || 'stone' => 'stone',
  _ => unit,
};

double? _kg(double? weight, String unit, int line) {
  if (weight == null) return null;
  return loadKg(_weightUnit(unit), weight) ??
      (throw ExternalWorkoutImportException(
        'Row $line: unsupported weight unit "$unit".',
      ));
}

List<List<dynamic>> _decode(String csv) =>
    CsvDecoder().convert(csv.replaceFirst(RegExp(r'^﻿'), ''));

List<String> _header(List<dynamic> row) =>
    row.map((v) => v.toString().trim().toLowerCase()).toList();

List<ImportedSet> _parse(
  List<List<dynamic>> rows,
  ExternalWorkoutFormat format,
) {
  if (rows.length < 2) {
    throw const ExternalWorkoutImportException('CSV needs a header and data.');
  }
  final header = _header(rows.first);
  if (header.toSet().length != header.length) {
    throw const ExternalWorkoutImportException('Duplicate CSV columns.');
  }
  final records = [
    for (var i = 1; i < rows.length; i++)
      if (rows[i].any((value) => value.toString().trim().isNotEmpty))
        CsvRecord(i + 1, header, rows[i]),
  ];
  final result = <ImportedSet>[];

  for (final row in records) {
    switch (format) {
      case ExternalWorkoutFormat.openGym:
        final day = row.require('date');
        final start = row.get('start_time');
        final workout = row.get('workout');
        final group = '$day|$start|$workout';
        final timestamp = row.date(start.isNotEmpty ? start : '$day 00:00:00');
        final duration = row.number('seconds');
        final distance = row.number('distance_km');
        final reps = row.number('reps');
        result.add(
          ImportedSet(
            group: group,
            timestamp: timestamp,
            name: row.require('exercise'),
            kind: distance != null || duration != null && reps == null
                ? 'cardio'
                : 'strength',
            unit: _weightUnit(row.get('unit')),
            reps: reps,
            load: _kg(row.number('weight'), row.get('unit'), row.line),
            durationMs: duration == null ? null : (duration * 1000).round(),
            distanceMetres: distance == null ? null : distance * 1000,
            incline: row.number('incline'),
            notes: _note(row.get('note'), row.get('set_note')),
          ),
        );
      case ExternalWorkoutFormat.liftLog:
        final timestamp = row.date(row.require('timestamp'));
        result.add(
          ImportedSet(
            group: row.require('sessionid'),
            timestamp: timestamp,
            name: row.require('exercise'),
            kind: 'strength',
            unit: _weightUnit(row.get('weightunit')),
            reps: row.number('reps'),
            load: _kg(row.number('weight'), row.get('weightunit'), row.line),
            notes: _note(row.get('notes'), ''),
          ),
        );
      case ExternalWorkoutFormat.fastNFitness:
        if (row.get('table').toUpperCase() != 'RECORD') continue;
        final timestamp = row.date(
          '${row.require('date')} ${row.require('time')}',
        );
        final kind = row.get('exercise_type').toLowerCase() == 'cardio'
            ? 'cardio'
            : 'strength';
        final count = row.number('sets') ?? 1;
        if (count > 100 || count != count.roundToDouble()) {
          throw ExternalWorkoutImportException(
            'Row ${row.line}: invalid number of sets ($count).',
          );
        }
        final seconds = row.number('seconds');
        final distance = row.number('distance');
        final distanceUnit = row.get('distance_unit').toLowerCase();
        if (distance != null &&
            distanceUnit != '' &&
            !['km', 'mi', 'mile'].contains(distanceUnit)) {
          throw ExternalWorkoutImportException(
            'Row ${row.line}: unsupported distance unit "$distanceUnit".',
          );
        }
        for (var set = 0; set < count; set++) {
          result.add(
            ImportedSet(
              group: '${row.get('date')}|${row.get('program_name')}',
              timestamp: timestamp,
              name: row.require('exercise'),
              kind: kind,
              unit: _weightUnit(row.get('weight_unit')),
              reps: kind == 'cardio' ? null : row.number('reps'),
              load: _kg(row.number('weight'), row.get('weight_unit'), row.line),
              durationMs: seconds == null ? null : (seconds * 1000).round(),
              distanceMetres: distance == null
                  ? null
                  : distance *
                        (distanceUnit == 'mi' || distanceUnit == 'mile'
                            ? 1609.344
                            : 1000),
              notes: _note(row.get('notes'), ''),
            ),
          );
        }
    }
  }

  if (result.isEmpty) {
    throw const ExternalWorkoutImportException('No workout sets in CSV.');
  }
  return result;
}

ExternalWorkoutFormat detectExternalWorkoutFormat(String csv) =>
    _detectFormat(_decode(csv));

ExternalWorkoutFormat _detectFormat(List<List<dynamic>> rows) {
  if (rows.isEmpty) {
    throw const ExternalWorkoutImportException('CSV file is empty.');
  }
  final header = _header(rows.first).toSet();
  if (header.containsAll(['date', 'start_time', 'exercise', 'set', 'unit'])) {
    return ExternalWorkoutFormat.openGym;
  }
  if (header.containsAll([
    'sessionid',
    'timestamp',
    'exercise',
    'weightunit',
    'reps',
  ])) {
    return ExternalWorkoutFormat.liftLog;
  }
  if (header.containsAll([
    'table',
    'date',
    'time',
    'exercise',
    'exercise_type',
    'sets',
  ])) {
    return ExternalWorkoutFormat.fastNFitness;
  }
  throw const ExternalWorkoutImportException(
    'Unsupported CSV. Select an openGym workouts, LiftLog, or '
    'Fast N Fitness Records export.',
  );
}

Object _setSignature(ExerciseSetsCompanion set) => (
  set.exerciseId.value,
  set.timestamp.value.millisecondsSinceEpoch ~/ 1000,
  set.reps.value,
  set.loadKg.value?.toStringAsFixed(5),
  set.durationMs.value,
  set.distanceMetres.value,
  set.incline.value,
  set.notes.value,
);

/// Appends workouts and exercises without clearing Flex history. Re-importing
/// the same file does not duplicate its sets (including identical set rows).
Future<ExternalWorkoutImportResult> importExternalWorkoutCsv(
  AppDatabase database,
  String csv,
) async {
  final rows = _decode(csv);
  final format = _detectFormat(rows);
  final imported = _parse(rows, format);
  final groups = <String, List<ImportedSet>>{};
  for (final set in imported) {
    groups.putIfAbsent(set.group, () => []).add(set);
  }

  return database.transaction(() async {
    final exercises = {
      for (final exercise in await database.exercises.select().get())
        exercise.name.toLowerCase(): exercise,
    };
    final workouts = await database.workouts.select().get();
    var exerciseCount = 0;
    var workoutCount = 0;
    var setCount = 0;

    for (final entries in groups.values) {
      final startedAt = entries
          .map((entry) => entry.timestamp)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      final existingWorkout = workouts
          .where((workout) => workout.startedAt.isAtSameMomentAs(startedAt))
          .firstOrNull;
      final workoutId =
          existingWorkout?.id ??
          await database.workouts.insertOne(
            WorkoutsCompanion.insert(startedAt: startedAt),
          );
      if (existingWorkout == null) workoutCount++;

      final existing =
          await (database.exerciseSets.select()
                ..where((set) => set.workoutId.equals(workoutId)))
              .get();
      final existingCounts = <Object, int>{};
      for (final set in existing) {
        final signature = _setSignature(set.toCompanion(false));
        existingCounts[signature] = (existingCounts[signature] ?? 0) + 1;
      }
      final seen = <Object, int>{};

      for (final entry in entries) {
        final name = entry.name.trim();
        var exercise = exercises[name.toLowerCase()];
        if (exercise == null) {
          exercise = await database.exercises.insertReturning(
            ExercisesCompanion.insert(
              name: name,
              kind: entry.kind,
              displayUnit: entry.unit,
            ),
          );
          exercises[name.toLowerCase()] = exercise;
          exerciseCount++;
        }
        final values = entry.values.copyWith(
          exerciseId: Value(exercise.id),
          workoutId: Value(workoutId),
        );
        final signature = _setSignature(values);
        seen[signature] = (seen[signature] ?? 0) + 1;
        if (seen[signature]! <= (existingCounts[signature] ?? 0)) continue;

        await database.exerciseSets.insertOne(values);
        setCount++;
      }
    }
    return ExternalWorkoutImportResult(
      format: format,
      workouts: workoutCount,
      exercises: exerciseCount,
      sets: setCount,
    );
  });
}
