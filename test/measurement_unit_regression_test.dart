import 'package:drift/drift.dart';
import 'package:flex/constants.dart';
import 'package:flex/database/body_weight_repository.dart';
import 'package:flex/database/database.dart';
import 'package:flex/database/exercise_analytics.dart';
import 'package:flex/database/exercise_set_repository.dart';
import 'package:flex/sets/edit_set_page.dart';
import 'package:flex/weight_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../integration_test/support/fixtures.dart';
import 'support/test_app.dart';

void main() {
  test(
    'strength measurements with distance or calorie units round-trip',
    () async {
      final harness = await FlexTestHarness.create();
      addTearDown(harness.database.close);
      await harness.database.settings.update().write(
        const SettingsCompanion(strengthUnit: Value('lb')),
      );

      for (final unit in ['m', 'km', 'mi', 'kcal']) {
        final name = 'Swim in $unit';
        final inserted = await insertExerciseSetFixture(
          harness.database,
          name,
          reps: 30,
          weight: 25,
          unit: unit,
        );
        final stored =
            await (harness.database.exerciseSets.select()
                  ..where((row) => row.id.equals(inserted.id)))
                .getSingle();
        expect(stored.loadKg, 25, reason: unit);

        final read = await getExerciseSetById(harness.database, inserted.id);
        expect(read!.unit, unit);
        expect(read.weight, 25);
        expect(read.reps, 30);

        await updateExerciseSet(
          harness.database,
          id: inserted.id,
          exerciseId: stored.exerciseId,
          exerciseSet: read.copyWith(weight: 50),
        );
        final updated = await getExerciseSetById(harness.database, inserted.id);
        expect(updated!.weight, 50, reason: unit);
        final graph = (await watchGraphs().first).singleWhere(
          (item) => item.name == name,
        );
        expect(graph.weight, 50, reason: unit);
        final values = await getStrengthData(
          name: name,
          target: unit,
          metric: StrengthMetric.bestWeight,
          period: Period.day,
          start: null,
          end: null,
          limit: 20,
        );
        expect(values.single.value, 50, reason: unit);
      }
    },
  );

  test('calorie-based cardio distance survives insert and edit', () async {
    final harness = await FlexTestHarness.create();
    addTearDown(harness.database.close);
    final inserted = await insertExerciseSetFixture(
      harness.database,
      'Calories',
      cardio: true,
      unit: 'kcal',
      distance: 320,
      duration: 20,
    );
    expect(inserted.distance, 320);
    final stored =
        await (harness.database.exerciseSets.select()
              ..where((row) => row.id.equals(inserted.id)))
            .getSingle();
    expect(stored.distanceMetres, 320);
  });

  testWidgets(
    'non-weight exercise entry labels its measurement and body weight',
    (tester) async {
      final harness = await FlexTestHarness.create();
      addTearDown(harness.database.close);
      await harness.database.settings.update().write(
        const SettingsCompanion(
          strengthUnit: Value('lb'),
          showUnits: Value(true),
          showBodyWeight: Value(true),
        ),
      );
      await harness.pump(
        tester,
        EditSetPage(
          exerciseSet: exerciseSetModelFixture(
            name: 'Swim',
            unit: 'm',
            reps: 30,
            weight: 25,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Distance (m)'), findsOneWidget);
      expect(find.bySemanticsLabel('Body weight (lb)'), findsOneWidget);
      expect(find.textContaining('One rep max'), findsNothing);

      final bodyField = find.bySemanticsLabel('Body weight (lb)');
      await tester.ensureVisible(bodyField);
      await tester.enterText(bodyField, '170');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final saved = (await getExerciseSets(harness.database)).single;
      expect(saved.reps, 30);
      expect(saved.weight, 25);
      expect(saved.unit, 'm');
      final stored =
          await (harness.database.exerciseSets.select()
                ..where((row) => row.id.equals(saved.id)))
              .getSingle();
      expect(stored.bodyWeightKg, closeTo(77.1107, 0.0001));
    },
  );

  testWidgets(
    'weight entry starts in the preferred unit and saves that value',
    (tester) async {
      final harness = await FlexTestHarness.create();
      addTearDown(harness.database.close);
      await harness.database.settings.update().write(
        const SettingsCompanion(strengthUnit: Value('lb')),
      );
      await harness.pump(tester, const WeightPage());
      await tester.pumpAndSettle();

      final dropdown = find.byWidgetPredicate(
        (widget) =>
            widget is DropdownButtonFormField<String> &&
            widget.decoration.labelText == 'Unit',
      );
      expect(
        tester.widget<DropdownButtonFormField<String>>(dropdown).initialValue,
        'lb',
      );

      await tester.enterText(find.byType(TextFormField).first, '180');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final latest = await getLatestBodyWeight(harness.database);
      expect(latest!.weightKg, closeTo(81.6466, 0.0001));
    },
  );
}
