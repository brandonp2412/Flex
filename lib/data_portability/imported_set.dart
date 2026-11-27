import 'package:drift/drift.dart';
import 'package:flex/database/database.dart';

final class ImportedSet {
  ImportedSet({
    required this.group,
    required DateTime timestamp,
    required this.name,
    required this.kind,
    required this.unit,
    double? reps,
    double? load,
    int? durationMs,
    double? distanceMetres,
    double? incline,
    String? notes,
  }) : values = ExerciseSetsCompanion(
         timestamp: Value(timestamp),
         reps: Value(reps),
         loadKg: Value(load),
         durationMs: Value(durationMs),
         distanceMetres: Value(distanceMetres),
         incline: Value(incline),
         notes: Value(notes),
       );

  final String group, name, kind, unit;
  final ExerciseSetsCompanion values;
  DateTime get timestamp => values.timestamp.value;
}
