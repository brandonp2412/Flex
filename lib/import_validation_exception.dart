final class ImportValidationException implements Exception {
  const ImportValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}
