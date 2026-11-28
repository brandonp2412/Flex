import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:flex/constants.dart';
import 'package:flex/database/body_weight_repository.dart';
import 'package:flex/database/database.dart';
import 'package:flex/database/defaults.dart';
import 'package:flex/database/exercise_set_repository.dart';
import 'package:flex/graph/cardio_data.dart';
import 'package:flex/graph/graph_data.dart';
import 'package:flex/graph/strength_data.dart';
import 'package:flex/main.dart';

class GraphExerciseSummary {
  GraphExerciseSummary({
    required this.exerciseId,
    required this.bodyWeight,
    required this.name,
    required this.unit,
    required this.cardio,
    required this.weight,
    required this.reps,
    required this.duration,
    required this.distance,
    required this.created,
    this.hasData = true,
    this.image,
    this.category,
  }) : normalizedName = name.toLowerCase();

  final int? exerciseId;
  final bool bodyWeight;
  final bool hasData;
  final String name;
  final String normalizedName;

  String get selectionKey =>
      bodyWeight ? 'body-weight' : 'exercise:$exerciseId';
  final String unit;
  final bool cardio;
  final double weight;
  final double reps;
  final double duration;
  final double distance;
  final DateTime created;
  final String? image;
  final String? category;
}

List<GraphExerciseSummary> filterGraphSummariesBySelection(
  Iterable<GraphExerciseSummary> summaries,
  Set<String> selection,
) => [
  for (final summary in summaries)
    if (selection.contains(summary.selectionKey)) summary,
];

typedef _CategoryPeriod = ({String category, DateTime start});

_CategoryPeriod _categoryPeriodKey(
  String category,
  DateTime created,
  Period period,
) => (category: category, start: _periodStart(created, period));

DateTime _periodStart(DateTime value, Period period) {
  final date = value.toLocal();
  return switch (period) {
    Period.day => DateTime(date.year, date.month, date.day),
    Period.month => DateTime(date.year, date.month),
    Period.year => DateTime(date.year),
    Period.week => _weekStart(date),
  };
}

DateTime _weekStart(DateTime date) {
  final monday = DateTime(date.year, date.month, date.day - date.weekday + 1);
  return monday.year < date.year ? DateTime(date.year) : monday;
}

Future<({Set<_CategoryPeriod> keys, DateTime? cutoff})> _latestGlobalBuckets({
  required AppDatabase database,
  required Period period,
  required DateTime? start,
  required DateTime? end,
  required int limit,
}) async {
  if (limit <= 0) return (keys: <_CategoryPeriod>{}, cutoff: null);

  const pageSize = 256;
  final keys = <_CategoryPeriod>{};
  DateTime? cutoff;
  var offset = 0;

  while (keys.length < limit) {
    final query = database.selectOnly(database.exerciseSets)
      ..join([
        innerJoin(
          database.exercises,
          database.exercises.id.equalsExp(database.exerciseSets.exerciseId),
        ),
        innerJoin(
          database.categories,
          database.categories.id.equalsExp(database.exercises.categoryId),
        ),
      ])
      ..addColumns([
        database.exerciseSets.id,
        database.exerciseSets.timestamp,
        database.categories.name,
      ])
      ..orderBy([
        OrderingTerm.desc(database.exerciseSets.timestamp),
        OrderingTerm.desc(database.exerciseSets.id),
      ])
      ..limit(pageSize, offset: offset);

    if (start != null) {
      query.where(database.exerciseSets.timestamp.isBiggerOrEqualValue(start));
    }
    if (end != null) {
      query.where(database.exerciseSets.timestamp.isSmallerThanValue(end));
    }

    final rows = await query.get();
    if (rows.isEmpty) break;

    for (final row in rows) {
      final created = row.read(database.exerciseSets.timestamp)!;
      final category = row.read(database.categories.name)!;
      final key = _categoryPeriodKey(category, created, period);
      if (!keys.add(key)) continue;

      final bucketStart = key.start;
      if (cutoff == null || bucketStart.isBefore(cutoff)) {
        cutoff = bucketStart;
      }
      if (keys.length == limit) break;
    }

    if (rows.length < pageSize || keys.length == limit) break;
    offset += rows.length;
  }

  return (keys: keys, cutoff: cutoff);
}

List<List<T>> _groupPeriods<T>(
  Iterable<T> rows,
  DateTime Function(T) timestamp,
  Period period,
  int limit,
) {
  final grouped = <DateTime, List<T>>{};
  for (final row in rows) {
    grouped
        .putIfAbsent(_periodStart(timestamp(row), period), () => [])
        .add(row);
  }

  final groups = grouped.values.toList();
  return groups.sublist(math.max(0, groups.length - limit));
}

double _loadInUnit(ExerciseSetView set, String target) {
  if (!isWeightUnit(set.unit)) return set.weight;
  final kg = loadKg(set.unit, set.weight);
  return displayLoad(target, kg);
}

double _distanceInUnit(ExerciseSetView set, String target) {
  final metres = distanceMetres(set.unit, set.distance);
  return displayDistance(target, metres);
}

ExerciseSetView _latest(List<ExerciseSetView> sets) =>
    sets.reduce((a, b) => a.created.isAfter(b.created) ? a : b);

ExerciseSetView _bestSet(
  List<ExerciseSetView> sets,
  double Function(ExerciseSetView) metric, [
  double Function(ExerciseSetView)? tieBreaker,
]) {
  return sets.reduce((a, b) {
    final first = metric(a), second = metric(b);
    if (second > first ||
        (first == second &&
            tieBreaker != null &&
            tieBreaker(b) > tieBreaker(a))) {
      return b;
    }
    return a;
  });
}

StrengthData _strengthBucket(
  List<ExerciseSetView> sets, {
  required StrengthMetric metric,
  required String target,
  String? category,
}) {
  late final ExerciseSetView representative;
  late final double value;

  switch (metric) {
    case StrengthMetric.bestWeight:
      representative = _bestSet(
        sets,
        (set) => _loadInUnit(set, target),
        (set) => set.reps,
      );
      value = _loadInUnit(representative, target);
      break;
    case StrengthMetric.bestReps:
      representative = _bestSet(sets, (set) => set.reps, (set) => set.weight);
      value = representative.reps;
      break;
    case StrengthMetric.oneRepMax:
      representative = _bestSet(
        sets,
        (set) => estimateOneRepMax(_loadInUnit(set, target), set.reps),
      );
      value = estimateOneRepMax(
        _loadInUnit(representative, target),
        representative.reps,
      );
      break;
    case StrengthMetric.volume:
      representative = _latest(sets);
      final volume = sets.fold<double>(
        0,
        (sum, set) => sum + _loadInUnit(set, target) * set.reps,
      );
      value = double.parse(volume.toStringAsFixed(2));
      break;
    case StrengthMetric.relativeStrength:
      representative = _bestSet(sets, (set) => set.weight, (set) => set.reps);
      value = representative.bodyWeight == 0
          ? 0
          : representative.weight / representative.bodyWeight;
      break;
  }

  return StrengthData(
    created: representative.created,
    value: value,
    unit: target,
    reps: representative.reps,
    category: category,
  );
}

Future<List<StrengthData>> getBodyWeightData({
  required String target,
  required Period period,
  required DateTime? start,
  required DateTime? end,
  required int limit,
}) async {
  final rows = await getBodyWeightHistory(
    db,
    limit: null,
    start: start,
    end: end,
    order: OrderingMode.asc,
  );
  return _bodyWeightPoints(rows, target, period, limit);
}

List<StrengthData> _bodyWeightPoints(
  List<BodyWeight> rows,
  String target,
  Period period,
  int limit,
) {
  return _groupPeriods(rows, (row) => row.timestamp, period, limit).map((
    group,
  ) {
    final row = group.last;
    return StrengthData(
      created: row.timestamp.toLocal(),
      value: displayLoad(target, row.weightKg),
      unit: target,
      reps: 1,
    );
  }).toList();
}

ExerciseSetQuery _exerciseSeriesQuery({
  required String name,
  required bool cardio,
  required DateTime? start,
  required DateTime? end,
}) => ExerciseSetQuery(
  db,
  exerciseName: name,
  cardio: cardio,
  startDate: cardio ? start ?? DateTime(0) : start,
  endDateExclusive: cardio
      ? end ?? DateTime.now().toLocal().add(const Duration(days: 1))
      : end,
  order: OrderingMode.asc,
);

List<GraphData> _exercisePoints(
  List<ExerciseSetView> sets,
  String target,
  Enum metric,
  Period period,
  int limit,
) => [
  for (final group in _groupPeriods(sets, (set) => set.created, period, limit))
    switch (metric) {
      CardioMetric value => _cardioBucket(group, metric: value, target: target),
      StrengthMetric value => _strengthBucket(
        group,
        metric: value,
        target: target,
        category: group.first.category,
      ),
      _ => throw ArgumentError.value(metric, 'metric'),
    },
];

Future<List<StrengthData>> getStrengthData({
  required String target,
  required String name,
  required StrengthMetric metric,
  required Period period,
  required DateTime? start,
  required DateTime? end,
  required int limit,
}) async {
  final sets = await _exerciseSeriesQuery(
    name: name,
    cardio: false,
    start: start,
    end: end,
  ).get();
  return _exercisePoints(
    sets,
    target,
    metric,
    period,
    limit,
  ).cast<StrengthData>();
}

double _averageIncline(List<ExerciseSetView> sets) {
  final values = sets
      .where((set) => set.incline != null)
      .map((set) => set.incline!)
      .toList();
  if (values.isEmpty) return 0;
  return values.reduce((a, b) => a + b) / values.length;
}

CardioData _cardioBucket(
  List<ExerciseSetView> sets, {
  required CardioMetric metric,
  required String target,
}) {
  final representative = _latest(sets);
  final duration = sets.fold<double>(0, (sum, set) => sum + set.duration);
  final incline = _averageIncline(sets);
  double distance() =>
      sets.fold<double>(0, (sum, set) => sum + _distanceInUnit(set, target));
  double pace() => duration == 0 ? 0 : distance() / duration;
  final value = switch (metric) {
    CardioMetric.pace => pace(),
    CardioMetric.distance => distance(),
    CardioMetric.duration => duration,
    CardioMetric.incline => incline,
    CardioMetric.inclineAdjustedPace =>
      pace() * math.pow(1.1, incline).toDouble(),
    CardioMetric.weight =>
      sets.map((set) => _loadInUnit(set, target)).fold<double>(0, math.max),
  };

  return CardioData(
    created: representative.created,
    value: double.parse(value.toStringAsFixed(2)),
    unit: target,
  );
}

Future<List<CardioData>> getCardioData({
  Period period = Period.day,
  String name = '',
  CardioMetric metric = CardioMetric.pace,
  String target = 'km',
  DateTime? start,
  DateTime? end,
  int limit = 11,
}) async {
  final sets = await _exerciseSeriesQuery(
    name: name,
    cardio: true,
    start: start,
    end: end,
  ).get();
  return _exercisePoints(
    sets,
    target,
    metric,
    period,
    limit,
  ).cast<CardioData>();
}

Future<List<StrengthData>> getGlobalData({
  AppDatabase? database,
  required String target,
  required StrengthMetric metric,
  required Period period,
  required DateTime? start,
  required DateTime? end,
  required int limit,
}) async {
  final source = database ?? db;
  final window = await _latestGlobalBuckets(
    database: source,
    period: period,
    start: start,
    end: end,
    limit: limit,
  );
  if (window.keys.isEmpty || window.cutoff == null) return [];

  final fetchStart = start != null && start.isAfter(window.cutoff!)
      ? start
      : window.cutoff;
  final allSets = await ExerciseSetQuery(
    source,
    startDate: fetchStart,
    endDateExclusive: end,
  ).get();

  final buckets = <_CategoryPeriod, List<ExerciseSetView>>{};
  for (final set in allSets) {
    final category = set.category;
    if (category == null) continue;
    final key = _categoryPeriodKey(category, set.created, period);
    if (!window.keys.contains(key)) continue;
    buckets.putIfAbsent(key, () => []).add(set);
  }

  final groups = buckets.values.toList();
  for (final group in groups) {
    group.sort((a, b) => a.created.compareTo(b.created));
  }
  groups.sort((a, b) => b.last.created.compareTo(a.last.created));

  return groups.reversed
      .map(
        (group) => _strengthBucket(
          group,
          metric: metric,
          target: target,
          category: group.first.category,
        ),
      )
      .toList();
}

Stream<List<GraphExerciseSummary>> watchGraphs() {
  return db
      .customSelect(
        '''
          SELECT
            exercises.id AS exercise_id,
            0 AS body_weight,
            exercises.name AS name,
            exercises.display_unit AS unit,
            CASE WHEN exercises.kind = 'cardio' THEN 1 ELSE 0 END AS cardio,
            exercises.image AS image,
            categories.name AS category,
            latest.load_kg AS load_kg,
            COALESCE(latest.reps, 0) AS reps,
            latest.duration_ms AS duration_ms,
            latest.distance_metres AS distance_metres,
            latest.timestamp AS timestamp
          FROM exercises
          LEFT JOIN categories ON categories.id = exercises.category_id
          LEFT JOIN exercise_sets AS latest ON latest.id = (
            SELECT exercise_sets.id
            FROM exercise_sets
            WHERE exercise_sets.exercise_id = exercises.id
            ORDER BY exercise_sets.timestamp DESC, exercise_sets.id DESC
            LIMIT 1
          )
          WHERE exercises.archived = 0
            AND (latest.id IS NOT NULL OR exercises.name NOT IN (${List.filled(defaultExercises.length, "?").join(", ")}))

          UNION ALL

          SELECT
            NULL AS exercise_id,
            1 AS body_weight,
            'Weight' AS name,
            'kg' AS unit,
            0 AS cardio,
            latest_weight.photo AS image,
            NULL AS category,
            latest_weight.weight_kg AS load_kg,
            1.0 AS reps,
            NULL AS duration_ms,
            NULL AS distance_metres,
            latest_weight.timestamp AS timestamp
          FROM body_weights AS latest_weight
          WHERE latest_weight.id = (
            SELECT body_weights.id
            FROM body_weights
            ORDER BY body_weights.timestamp DESC, body_weights.id DESC
            LIMIT 1
          )

          ORDER BY timestamp DESC NULLS FIRST, name COLLATE NOCASE
        ''',
        variables: [for (final entry in defaultExercises) Variable(entry.$1)],
        readsFrom: {
          db.exercises,
          db.categories,
          db.exerciseSets,
          db.bodyWeights,
        },
      )
      .watch()
      .map(
        (results) => results.map((result) {
          final unit = result.read<String>('unit');
          final timestamp = result.readNullable<int>('timestamp');
          return GraphExerciseSummary(
            exerciseId: result.readNullable<int>('exercise_id'),
            bodyWeight: result.read<int>('body_weight') != 0,
            hasData: timestamp != null,
            name: result.read<String>('name'),
            unit: unit,
            cardio: result.read<int>('cardio') != 0,
            weight: displayLoad(unit, result.readNullable<double>('load_kg')),
            reps: result.read<double>('reps'),
            duration: (result.readNullable<int>('duration_ms') ?? 0) / 60000,
            distance: displayDistance(
              unit,
              result.readNullable<double>('distance_metres'),
            ),
            created: timestamp == null
                ? DateTime.fromMillisecondsSinceEpoch(0).toLocal()
                : DateTime.fromMillisecondsSinceEpoch(
                    timestamp * 1000,
                  ).toLocal(),
            image: result.readNullable<String>('image'),
            category: result.readNullable<String>('category'),
          );
        }).toList(),
      );
}

Future<List<ExerciseSetView>> getBodyWeightGraphHistory({
  int limit = 20,
}) async {
  final rows = await getBodyWeightHistory(db, limit: limit);
  return _bodyWeightHistoryViews(rows);
}

List<ExerciseSetView> _bodyWeightHistoryViews(List<BodyWeight> rows) => rows
    .map(
      (row) => ExerciseSetView(
        id: row.id,
        cardio: false,
        created: row.timestamp.toLocal(),
        image: row.photo,
        name: 'Weight',
        reps: 1,
        unit: 'kg',
        weight: row.weightKg,
      ),
    )
    .toList();

Stream<List<GraphData>> watchInitialGraphData(GraphExerciseSummary summary) {
  final cardio = summary.cardio && !summary.bodyWeight;
  return watchExerciseGraphData(
    name: summary.name,
    target: summary.unit,
    bodyWeight: summary.bodyWeight,
    metric: cardio
        ? (isWeightUnit(summary.unit) ? CardioMetric.weight : CardioMetric.pace)
        : StrengthMetric.bestWeight,
    limit: cardio ? 11 : 20,
  );
}

Stream<List<ExerciseSetView>> watchGraphHistory(
  String name, {
  required bool bodyWeight,
  required int limit,
}) => bodyWeight
    ? watchBodyWeightHistory(db, limit: limit).map(_bodyWeightHistoryViews)
    : ExerciseSetQuery(db, exerciseName: name, limit: limit).watch();

Stream<List<GraphData>> watchExerciseGraphData({
  required String name,
  required String target,
  required Enum metric,
  bool bodyWeight = false,
  Period period = Period.day,
  DateTime? start,
  DateTime? end,
  required int limit,
}) => bodyWeight
    ? watchBodyWeightHistory(
        db,
        limit: null,
        start: start,
        end: end,
        order: OrderingMode.asc,
      ).map((rows) => _bodyWeightPoints(rows, target, period, limit))
    : _exerciseSeriesQuery(
        name: name,
        cardio: metric is CardioMetric,
        start: start,
        end: end,
      ).watch().map(
        (sets) => _exercisePoints(sets, target, metric, period, limit),
      );

Stream<({List<StrengthData> data, List<String> categories})> watchGlobalData({
  required AppDatabase database,
  required String target,
  required StrengthMetric metric,
  required Period period,
  required DateTime? start,
  required DateTime? end,
  required int limit,
}) => database
    .customSelect(
      'SELECT 1',
      readsFrom: {
        database.exerciseSets,
        database.exercises,
        database.categories,
      },
    )
    .watch()
    .asyncMap(
      (_) => database.transaction(() async {
        final data = await getGlobalData(
          database: database,
          target: target,
          metric: metric,
          period: period,
          start: start,
          end: end,
          limit: limit,
        );
        final categories =
            await (database.categories.select()
                  ..orderBy([(row) => OrderingTerm.asc(row.name)]))
                .map((row) => row.name)
                .get();
        return (data: data, categories: categories);
      }),
    );
