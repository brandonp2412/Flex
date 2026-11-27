import 'package:flex/data_portability/external_workout_format.dart';

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
