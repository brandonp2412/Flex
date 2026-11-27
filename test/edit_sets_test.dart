import 'package:flex/database/exercise_set_repository.dart';
import 'package:flex/sets/edit_sets_page.dart';
import 'package:flex/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../integration_test/support/fixtures.dart';
import 'support/test_app.dart';

import 'package:drift/drift.dart';

void main() {
  testWidgets('EditSetsPage cardio toggle switches fields', (
    WidgetTester tester,
  ) async {
    final harness = await FlexTestHarness.create();
    await harness.database.settings.update().write(
      testSettings(showUnits: true),
    );
    final ids = [
      (await insertExerciseSetFixture(
        harness.database,
        'Bench press',
        reps: 2,
        weight: 90,
        created: DateTime.now(),
      )).id,
      (await insertExerciseSetFixture(
        harness.database,
        'Deadlift',
        reps: 5,
        weight: 100,
        created: DateTime.now(),
      )).id,
    ];

    await harness.pump(tester, EditSetsPage(ids: ids));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Reps'), findsOne);
    expect(find.bySemanticsLabel('Distance'), findsNothing);

    final selector = find.byKey(const Key('exercise-kind-selector'));
    final cardio = find.descendant(of: selector, matching: find.text('Cardio'));
    final strength = find.descendant(
      of: selector,
      matching: find.text('Strength'),
    );

    await tester.tap(cardio);
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Reps'), findsNothing);
    expect(find.bySemanticsLabel('Weight'), findsOne);
    expect(find.bySemanticsLabel('Distance'), findsNothing);

    final unitDropdown = find.byWidgetPredicate(
      (widget) =>
          widget is DropdownButtonFormField<String> &&
          widget.decoration.labelText == 'Unit',
    );
    await tester.tap(unitDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kilometers (km)').last);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Weight'), findsNothing);
    expect(find.bySemanticsLabel('Distance'), findsOne);

    await tester.tap(strength);
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Reps'), findsOne);
  });

  testWidgets('EditExerciseSets', (WidgetTester tester) async {
    final harness = await FlexTestHarness.create();
    await harness.database.settings.update().write(
      testSettings(showUnits: true),
    );
    final ids = [
      (await insertExerciseSetFixture(
        harness.database,
        'Bench press',
        reps: 2,
        weight: 90,
        created: DateTime.now(),
        category: 'Chest',
      )).id,
      (await insertExerciseSetFixture(
        harness.database,
        'Shoulder press',
        reps: 5,
        weight: 60,
        created: DateTime.now(),
        category: 'Shoulders',
      )).id,
      (await insertExerciseSetFixture(
        harness.database,
        'Deadlift',
        reps: 7,
        weight: 100,
        created: DateTime.now(),
        category: 'Legs',
      )).id,
    ];

    await harness.pump(tester, EditSetsPage(ids: ids));

    expect(find.text('Edit 3 sets'), findsOne);
    expect(find.bySemanticsLabel('Name'), findsOne);
    expect(find.bySemanticsLabel('Reps'), findsOne);

    await tester.enterText(find.bySemanticsLabel('Name'), 'New name');
    await tester.pump();
    await tester.enterText(find.bySemanticsLabel('Reps'), '9');
    await tester.pump();
    await tester.enterText(find.bySemanticsLabel('Weight'), '200');
    await tester.pump();
    final unitDropdown = find.byWidgetPredicate(
      (widget) =>
          widget is DropdownButtonFormField<String> &&
          widget.decoration.labelText == 'Unit',
    );
    await tester.tap(unitDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pounds (lb)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Edit 3 sets'), findsNothing);
    final exerciseSets = (await ExerciseSetQuery(harness.database).get())
        .where(
          (set) =>
              ids.contains(set.id) &&
              set.reps == 9 &&
              set.weight == 200 &&
              set.name == 'New name',
        )
        .toList();
    expect(exerciseSets.length, equals(3));
  });

  testWidgets(
    'bulk cardio edit preserves blank fields and fractional incline',
    (tester) async {
      final harness = await FlexTestHarness.create();
      final ids = [
        for (final distance in [2.0, 3.0])
          (await insertExerciseSetFixture(
            harness.database,
            'Treadmill',
            cardio: true,
            unit: 'km',
            distance: distance,
            duration: 20,
            incline: 2.5,
          )).id,
      ];
      await harness.pump(tester, EditSetsPage(ids: ids));
      await tester.pumpAndSettle();
      await tester.enterText(find.bySemanticsLabel('Name'), 'Run');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final saved = await ExerciseSetQuery(harness.database, ids: ids).get();
      expect(saved.map((set) => set.name).toSet(), {'Run'});
      expect(saved.map((set) => set.distance).toSet(), {2.0, 3.0});
      expect(saved.map((set) => set.duration).toSet(), {20.0});
      expect(saved.map((set) => set.incline).toSet(), {2.5});
    },
  );
  testWidgets('bulk cardio edit accepts localized fractional incline', (
    tester,
  ) async {
    const locale = Locale('de');
    final l10n = lookupAppLocalizations(locale);
    final harness = await FlexTestHarness.create();
    final set = await insertExerciseSetFixture(
      harness.database,
      'Run',
      cardio: true,
      unit: 'km',
      distance: 3,
      duration: 20,
      incline: 2.5,
    );
    await harness.pump(tester, EditSetsPage(ids: [set.id]), locale: locale);
    await tester.pumpAndSettle();
    await tester.enterText(find.bySemanticsLabel(l10n.inclinePercent), '3,75');
    await tester.tap(find.text(l10n.actionSave));
    await tester.pumpAndSettle();
    final saved = await ExerciseSetQuery(
      harness.database,
      ids: [set.id],
    ).firstOrNull();
    expect(saved!.incline, 3.75);
    expect(saved.distance, 3);
    expect(saved.duration, 20);
  });
}
