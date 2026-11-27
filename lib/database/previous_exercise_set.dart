import 'package:flex/database/set_performance.dart';

class PreviousExerciseSet implements SetPerformance {
  const PreviousExerciseSet({
    required this.cardio,
    required this.unit,
    required this.reps,
    required this.weight,
    required this.distance,
    required this.duration,
    required this.incline,
  });

  final bool cardio;
  final String unit;
  @override
  final double reps;
  @override
  final double weight;
  @override
  final double distance;
  @override
  final double duration;
  @override
  final int? incline;
}
