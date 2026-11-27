final class GraphCsvImportException implements Exception {
  const GraphCsvImportException(this.message);

  final String message;

  @override
  String toString() => message;
}
