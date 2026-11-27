final class ImportedSet {
  const ImportedSet({
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
