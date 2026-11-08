import 'package:csv/csv.dart';
import 'package:drift/drift.dart';
import 'package:flex/database/database.dart';

/// CSV layouts are verified against each app's own export implementation:
/// openGym: frontend/src/lib/export-csv.js
/// LiftLog: app/src/store/settings/export-plaintext-effects.ts
/// Fast N Fitness: app/src/main/java/com/easyfitness/DAO/export/CVSManager.java
enum ExternalWorkoutFormat { openGym, liftLog, fastNFitness }

final class ExternalWorkoutImportException implements Exception {
  const ExternalWorkoutImportException(this.message);
  final String message;

  @override
  String toString() => message;
}

final class ExternalWorkoutImportResult {
  const ExternalWorkoutImportResult({
    required this.format,
    required this.workouts,
    required this.exercises,
    required this.sets,
  });

  final ExternalWorkoutFormat format;
  final int workouts;
  final int exercises;
  final int sets;
}

final class _ImportedSet {
  const _ImportedSet({
    required this.group,
    required this.timestamp,
    required this.name,
    required this.kind,
    required this.unit,
    this.reps,
    this.load,
    this.durationMs,
    this.distanceMetres,
    this.incline,
    this.notes,
  });

  final String group;
  final DateTime timestamp;
  final String name;
  final String kind;
  final String unit;
  final double? reps;
  final double? load;
  final int? durationMs;
  final double? distanceMetres;
  final double? incline;
  final String? notes;
}

final class _CsvRecord {
  _CsvRecord(this.line, this.columns, List<String> header, List<dynamic> values)
    : fields = {
        for (var i = 0; i < header.length; i++)
          header[i]: i < values.length ? values[i].toString().trim() : '',
      };

  final int line;
  final String columns;
  final Map<String, String> fields;

  String get(String name) => fields[name.toLowerCase()] ?? '';

  String require(String name) {
    final value = get(name);
    if (value.isEmpty) {
      throw ExternalWorkoutImportException('Row $line: missing $name.');
    }
    return value;
  }

  double? number(String name) {
    final value = get(name);
    if (value.isEmpty) return null;
    final parsed = double.tryParse(value);
    if (parsed == null || !parsed.isFinite || parsed < 0) {
      throw ExternalWorkoutImportException(
        'Row $line: invalid $name ($value).',
      );
    }
    return parsed;
  }

  DateTime date(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) {
      throw ExternalWorkoutImportException('Row $line: invalid date ($value).');
    }
    return DateTime.fromMillisecondsSinceEpoch(
      date.millisecondsSinceEpoch ~/ 1000 * 1000,
      isUtc: date.isUtc,
    );
  }
}

String? _note(String a, String b) {
  final parts = [a, b].where((part) => part.isNotEmpty).toSet();
  return parts.isEmpty ? null : parts.join(' · ');
}

double? _kg(double? weight, String unit, int line) {
  if (weight == null) return null;
  return switch (unit.toLowerCase()) {
    'kg' || 'kgs' || '' => weight,
    'lb' || 'lbs' => weight * 0.45359237,
    'st' || 'stone' => weight * 6.35029318,
    _ => throw ExternalWorkoutImportException(
      'Row $line: unsupported weight unit "$unit".',
    ),
  };
}

List<_ImportedSet> _parse(String csv, ExternalWorkoutFormat format) {
  final rows = CsvDecoder().convert(csv.replaceFirst(RegExp(r'^\uFEFF'), ''));
  if (rows.length < 2) {
    throw const ExternalWorkoutImportException('CSV needs a header and data.');
  }
  final header = rows.first
      .map((v) => v.toString().trim().toLowerCase())
      .toList();
  if (header.toSet().length != header.length) {
    throw const ExternalWorkoutImportException('Duplicate CSV columns.');
  }
  final records = [
    for (var i = 1; i < rows.length; i++)
      if (rows[i].any((value) => value.toString().trim().isNotEmpty))
        _CsvRecord(i + 1, '', header, rows[i]),
  ];
  final result = <_ImportedSet>[];

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
          _ImportedSet(
            group: group,
            timestamp: timestamp,
            name: row.require('exercise'),
            kind: distance != null || duration != null && reps == null
                ? 'cardio'
                : 'strength',
            unit: row.get('unit').isEmpty ? 'kg' : row.get('unit'),
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
          _ImportedSet(
            group: row.require('sessionid'),
            timestamp: timestamp,
            name: row.require('exercise'),
            kind: 'strength',
            unit: row.get('weightunit').isEmpty ? 'kg' : row.get('weightunit'),
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
            _ImportedSet(
              group: '${row.get('date')}|${row.get('program_name')}',
              timestamp: timestamp,
              name: row.require('exercise'),
              kind: kind,
              unit: row.get('weight_unit').isEmpty
                  ? 'kg'
                  : row.get('weight_unit'),
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

ExternalWorkoutFormat detectExternalWorkoutFormat(String csv) {
  final rows = CsvDecoder().convert(csv.replaceFirst(RegExp(r'^\uFEFF'), ''));
  if (rows.isEmpty) {
    throw const ExternalWorkoutImportException('CSV file is empty.');
  }
  final header = rows.first
      .map((v) => v.toString().trim().toLowerCase())
      .toSet();
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

String _setSignature(
  int exerciseId,
  DateTime timestamp,
  double? reps,
  double? load,
  int? durationMs,
  double? distanceMetres,
  double? incline,
  String? notes,
) => [
  exerciseId,
  timestamp.millisecondsSinceEpoch ~/ 1000,
  reps,
  load?.toStringAsFixed(5),
  durationMs,
  distanceMetres,
  incline,
  notes,
].join('|');

/// Appends workouts and exercises without clearing Flex history. Re-importing
/// the same file does not duplicate its sets (including identical set rows).
Future<ExternalWorkoutImportResult> importExternalWorkoutCsv(
  AppDatabase database,
  String csv,
) async {
  final format = detectExternalWorkoutFormat(csv);
  final imported = _parse(csv, format);
  final groups = <String, List<_ImportedSet>>{};
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
      final existingCounts = <String, int>{};
      for (final set in existing) {
        final signature = _setSignature(
          set.exerciseId,
          set.timestamp,
          set.reps,
          set.loadKg,
          set.durationMs,
          set.distanceMetres,
          set.incline,
          set.notes,
        );
        existingCounts[signature] = (existingCounts[signature] ?? 0) + 1;
      }
      final seen = <String, int>{};

      for (final entry in entries) {
        final name = entry.name.trim();
        var exercise = exercises[name.toLowerCase()];
        if (exercise == null) {
          final id = await database.exercises.insertOne(
            ExercisesCompanion.insert(
              name: name,
              kind: entry.kind,
              displayUnit: entry.unit,
            ),
          );
          exercise =
              await (database.exercises.select()
                    ..where((row) => row.id.equals(id)))
                  .getSingle();
          exercises[name.toLowerCase()] = exercise;
          exerciseCount++;
        }
        final signature = _setSignature(
          exercise.id,
          entry.timestamp,
          entry.reps,
          entry.load,
          entry.durationMs,
          entry.distanceMetres,
          entry.incline,
          entry.notes,
        );
        seen[signature] = (seen[signature] ?? 0) + 1;
        if (seen[signature]! <= (existingCounts[signature] ?? 0)) continue;

        await database.exerciseSets.insertOne(
          ExerciseSetsCompanion.insert(
            exerciseId: exercise.id,
            workoutId: Value(workoutId),
            timestamp: entry.timestamp,
            reps: Value(entry.reps),
            loadKg: Value(entry.load),
            durationMs: Value(entry.durationMs),
            distanceMetres: Value(entry.distanceMetres),
            incline: Value(entry.incline),
            notes: Value(entry.notes),
          ),
        );
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
