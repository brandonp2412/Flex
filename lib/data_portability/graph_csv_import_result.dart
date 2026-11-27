final class GraphCsvImportResult {
  const GraphCsvImportResult({
    required this.exercises,
    required this.workouts,
    required this.exerciseSets,
    required this.bodyWeights,
  });

  final int exercises;
  final int workouts;
  final int exerciseSets;
  final int bodyWeights;
}
