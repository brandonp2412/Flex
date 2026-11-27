final class ExternalWorkoutImportException implements Exception {
  const ExternalWorkoutImportException(this.message);
  final String message;

  @override
  String toString() => message;
}
