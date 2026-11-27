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
    final query = db.selectOnly(db.exerciseSets)
      ..join([
        innerJoin(
          db.exercises,
          db.exercises.id.equalsExp(db.exerciseSets.exerciseId),
        ),
        innerJoin(
          db.categories,
          db.categories.id.equalsExp(db.exercises.categoryId),
        ),
      ])
      ..addColumns([
        db.exerciseSets.id,
        db.exerciseSets.timestamp,
        db.categories.name,
      ])
      ..orderBy([
        OrderingTerm.desc(db.exerciseSets.timestamp),
        OrderingTerm.desc(db.exerciseSets.id),
      ])
      ..limit(pageSize, offset: offset);

    if (start != null) {
      query.where(db.exerciseSets.timestamp.isBiggerOrEqualValue(start));
    }
    if (end != null) {
      query.where(db.exerciseSets.timestamp.isSmallerThanValue(end));
    }

    final rows = await query.get();
    if (rows.isEmpty) break;

    for (final row in rows) {
      final created = row.read(db.exerciseSets.timestamp)!;
      final category = row.read(db.categories.name)!;
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

Future<List<List<ExerciseSetView>>> _exerciseBuckets({
  required String name,
  required bool cardio,
  required Period period,
  required DateTime? start,
  required DateTime? end,
  required int limit,
}) async {
  final sets = await ExerciseSetQuery(
    db,
    exerciseName: name,
    startDate: start,
    endDateExclusive: end,
    order: OrderingMode.asc,
  ).get();
  return _groupPeriods(
    sets.where((set) => set.cardio == cardio),
    (set) => set.created,
    period,
    limit,
  );
}

Future<List<StrengthData>> getStrengthData({
  required String target,
  required String name,
  required StrengthMetric metric,
  required Period period,
  required DateTime? start,
  required DateTime? end,
  required int limit,
}) async {
  final groups = await _exerciseBuckets(
    name: name,
    cardio: false,
    period: period,
    start: start,
    end: end,
    limit: limit,
  );
  return [
    for (final group in groups)
      _strengthBucket(
        group,
        metric: metric,
        target: target,
        category: group.first.category,
      ),
  ];
}

double _averageIncline(List<ExerciseSetView> sets) {
  final values = sets
      .where((set) => set.incline != null)
      .map((set) => set.incline!.toDouble())
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
  final groups = await _exerciseBuckets(
    name: name,
    cardio: true,
    period: period,
    start: start ?? DateTime(0),
    end: end ?? DateTime.now().toLocal().add(const Duration(days: 1)),
    limit: limit,
  );
  return [
    for (final group in groups)
      _cardioBucket(group, metric: metric, target: target),
  ];
}

Future<List<StrengthData>> getGlobalData({
  required String target,
  required StrengthMetric metric,
  required Period period,
  required DateTime? start,
  required DateTime? end,
  required int limit,
}) async {
  final window = await _latestGlobalBuckets(
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
    db,
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
  return rows
      .map(
        (row) => ExerciseSetView(
          id: row.id,
          bodyWeight: 0,
          cardio: false,
          created: row.timestamp.toLocal(),
          distance: 0,
          duration: 0,
          image: row.photo,
          name: 'Weight',
          reps: 1,
          unit: 'kg',
          weight: row.weightKg,
        ),
      )
      .toList();
}

Future<List<GraphData>> getExerciseGraphData({
  required String name,
  required String target,
  required Enum metric,
  bool bodyWeight = false,
  Period period = Period.day,
  DateTime? start,
  DateTime? end,
  required int limit,
}) => bodyWeight
    ? getBodyWeightData(
        target: target,
        period: period,
        start: start,
        end: end,
        limit: limit,
      )
    : switch (metric) {
        CardioMetric value => getCardioData(
          name: name,
          target: target,
          metric: value,
          period: period,
          start: start,
          end: end,
          limit: limit,
        ),
        StrengthMetric value => getStrengthData(
          name: name,
          target: target,
          metric: value,
          period: period,
          start: start,
          end: end,
          limit: limit,
        ),
        _ => throw ArgumentError.value(metric, 'metric'),
      };

Future<List<GraphData>> getInitialGraphData(GraphExerciseSummary summary) {
  final cardio = summary.cardio && !summary.bodyWeight;
  return getExerciseGraphData(
    name: summary.name,
    target: summary.unit,
    bodyWeight: summary.bodyWeight,
    metric: cardio
        ? (isWeightUnit(summary.unit) ? CardioMetric.weight : CardioMetric.pace)
        : StrengthMetric.bestWeight,
    limit: cardio ? 11 : 20,
  );
}
