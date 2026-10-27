import 'package:drift/drift.dart';
import 'package:flex/database/database.dart';
import 'package:flex/measurement_units.dart';

double displayBodyWeight(String unit, double weightKg) =>
    displayLoad(unit, weightKg);

double? toKg(String unit, double value) => loadKg(unit, value);

Future<BodyWeight?> getLatestBodyWeight(AppDatabase database) {
  return (database.bodyWeights.select()
        ..orderBy([
          (row) =>
              OrderingTerm(expression: row.timestamp, mode: OrderingMode.desc),
          (row) => OrderingTerm(expression: row.id, mode: OrderingMode.desc),
        ])
        ..limit(1))
      .getSingleOrNull();
}

Future<List<BodyWeight>> getBodyWeightHistory(
  AppDatabase database, {
  int limit = 20,
}) {
  return (database.bodyWeights.select()
        ..orderBy([
          (row) =>
              OrderingTerm(expression: row.timestamp, mode: OrderingMode.desc),
          (row) => OrderingTerm(expression: row.id, mode: OrderingMode.desc),
        ])
        ..limit(limit))
      .get();
}

Future<int> recordBodyWeight(
  AppDatabase database, {
  required DateTime timestamp,
  required double weightKg,
  String? photo,
}) {
  return database.bodyWeights.insertOne(
    BodyWeightsCompanion.insert(
      timestamp: timestamp,
      weightKg: weightKg,
      photo: Value(photo),
    ),
  );
}
