import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flex/database/categories.dart';
import 'package:flex/database/database.dart';
import 'package:flex/database/exercise_catalog.dart';
import 'package:flex/measurement_units.dart';

Future<void> bulkEditExerciseSets(
  AppDatabase database,
  Iterable<int> ids, {
  String? name,
  String? unit,
  bool? cardio,
  String? category,
  DateTime? timestamp,
  double? reps,
  double? weight,
  double? distance,
  int? durationMs,
  double? incline,
  double? bodyWeight,
  String preferredStrengthUnit = 'last-entry',
}) async {
  final selection = jsonEncode(ids.toSet().toList());
  const selected = 'SELECT value FROM json_each(?)';
  final rename = name?.trim();
  final changesDefinition = unit != null || cardio != null || category != null;

  await database.transaction(() async {
    final assignments = <String>[];
    final variables = <Variable>[];
    void assign(String column, Object value) {
      assignments.add('$column = ?');
      variables.add(switch (value) {
        int v => Variable<int>(v),
        double v => Variable<double>(v),
        DateTime v => Variable<DateTime>(v),
        _ => throw ArgumentError.value(value),
      });
    }

    const effectiveUnit = '''
      (SELECT CASE
        WHEN exercises.kind = 'strength'
          AND exercises.display_unit IN ('kg', 'lb', 'stone')
          AND settings.strength_unit <> 'last-entry'
        THEN settings.strength_unit ELSE exercises.display_unit END
       FROM exercises LEFT JOIN settings ON 1 = 1
       WHERE exercises.id = exercise_sets.exercise_id)
    ''';

    void scaled(
      String column,
      double value,
      Map<String, double> factors, {
      double fallback = 1.0,
    }) {
      if (unit != null) {
        assign(column, value * (factors[unit] ?? fallback));
      } else {
        final cases = factors.entries
            .map((e) => "WHEN '${e.key}' THEN ${e.value}")
            .join(' ');
        assignments.add(
          '$column = ? * CASE $effectiveUnit $cases ELSE $fallback END',
        );
        variables.add(Variable<double>(value));
      }
    }

    if (reps != null) assign('reps', reps);
    if (weight != null) scaled('load_kg', weight, weightUnitFactors);
    if (distance != null)
      scaled('distance_metres', distance, distanceUnitFactors);
    if (durationMs != null) assign('duration_ms', durationMs);
    if (incline != null) assign('incline', incline);
    if (timestamp != null) assign('timestamp', timestamp);
    if (bodyWeight != null) {
      final fallback = weightUnitFactors[preferredStrengthUnit] ?? 1.0;
      scaled(
        'body_weight_kg',
        bodyWeight,
        weightUnitFactors,
        fallback: fallback,
      );
    }

    int? targetId;
    if (rename != null && rename.isNotEmpty) {
      final target = await getExerciseByName(
        database,
        rename,
        includeArchived: true,
      );
      if (target != null) {
        targetId = target.id;
      } else {
        final sourceId = await database
            .customSelect(
              'SELECT exercise_id FROM exercise_sets WHERE id IN ($selected) '
              'ORDER BY timestamp DESC, id DESC LIMIT 1',
              variables: [Variable<String>(selection)],
              readsFrom: {database.exerciseSets},
            )
            .getSingleOrNull();
        if (sourceId != null) {
          final source =
              await (database.exercises.select()..where(
                    (e) => e.id.equals(sourceId.read<int>('exercise_id')),
                  ))
                  .getSingle();
          targetId = (await createExerciseDefinition(
            database,
            name: rename,
            cardio: cardio ?? (source.kind == 'cardio'),
            displayUnit: unit ?? source.displayUnit,
            category:
                category ?? await getExerciseCategoryName(database, source),
            image: source.image,
            defaultRestDurationMs: source.defaultRestDurationMs,
          )).id;
        }
      }
      if (targetId != null) assign('exercise_id', targetId);
    }

    if (assignments.isNotEmpty) {
      await database.customUpdate(
        'UPDATE exercise_sets SET ${assignments.join(', ')} '
        'WHERE id IN ($selected)',
        variables: [...variables, Variable<String>(selection)],
        updates: {database.exerciseSets},
        updateKind: UpdateKind.update,
      );
    }

    if (changesDefinition || targetId != null) {
      final categoryId = category == null
          ? null
          : await ensureCategoryId(database, category);
      final definition = ExercisesCompanion(
        kind: cardio == null
            ? const Value.absent()
            : Value(cardio ? 'cardio' : 'strength'),
        displayUnit: unit == null ? const Value.absent() : Value(unit),
        categoryId: category == null ? const Value.absent() : Value(categoryId),
        archived: targetId == null ? const Value.absent() : const Value(false),
      );
      final affected = database.customSelect(
        'SELECT DISTINCT exercise_id FROM exercise_sets WHERE id IN ($selected)',
        variables: [Variable<String>(selection)],
        readsFrom: {database.exerciseSets},
      );
      final exerciseIds = (await affected.get())
          .map((row) => row.read<int>('exercise_id'))
          .toList();
      if (exerciseIds.isNotEmpty) {
        await (database.exercises.update()
              ..where((e) => e.id.isIn(exerciseIds)))
            .write(definition);
      }
    }
  });
}
