import 'package:drift/drift.dart';
import 'package:flex/database/database.dart';

Future<BodyWeight?> getLatestBodyWeight(AppDatabase database) async =>
    (await getBodyWeightHistory(database, limit: 1)).firstOrNull;

Future<List<BodyWeight>> getBodyWeightHistory(
  AppDatabase database, {
  int? limit = 20,
  DateTime? start,
  DateTime? end,
  OrderingMode order = OrderingMode.desc,
}) {
  return _bodyWeightHistory(
    database,
    limit: limit,
    start: start,
    end: end,
    order: order,
  ).get();
}

Stream<List<BodyWeight>> watchBodyWeightHistory(
  AppDatabase database, {
  int? limit = 20,
  DateTime? start,
  DateTime? end,
  OrderingMode order = OrderingMode.desc,
}) => _bodyWeightHistory(
  database,
  limit: limit,
  start: start,
  end: end,
  order: order,
).watch();

Selectable<BodyWeight> _bodyWeightHistory(
  AppDatabase database, {
  required int? limit,
  required DateTime? start,
  required DateTime? end,
  required OrderingMode order,
}) {
  final query = database.bodyWeights.select()
    ..orderBy([
      (row) => OrderingTerm(expression: row.timestamp, mode: order),
      (row) => OrderingTerm(expression: row.id, mode: order),
    ]);
  if (start != null)
    query.where((row) => row.timestamp.isBiggerOrEqualValue(start));
  if (end != null) query.where((row) => row.timestamp.isSmallerThanValue(end));
  if (limit != null) query.limit(limit);
  return query;
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

Future<BodyWeight?> getBodyWeightById(AppDatabase database, int id) =>
    (database.bodyWeights.select()..where((row) => row.id.equals(id)))
        .getSingleOrNull();

Future<int> updateBodyWeight(
  AppDatabase database, {
  required int id,
  required double weightKg,
  String? photo,
}) => (database.bodyWeights.update()..where((row) => row.id.equals(id))).write(
  BodyWeightsCompanion(weightKg: Value(weightKg), photo: Value(photo)),
);

Future<int> deleteBodyWeight(AppDatabase database, int id) =>
    database.bodyWeights.deleteWhere((row) => row.id.equals(id));
