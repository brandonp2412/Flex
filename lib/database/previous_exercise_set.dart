class PreviousExerciseSet {
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
  final double reps;
  final double weight;
  final double distance;
  final double duration;
  final int? incline;
}
