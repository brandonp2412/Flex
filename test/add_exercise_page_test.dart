import 'package:flex/graph/exercise_editor_page.dart';
import 'package:flex/database/exercise_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  testWidgets('duplicate name is rejected and can be corrected', (
    tester,
  ) async {
    final harness = await FlexTestHarness.create();
    await createExerciseDefinition(
      harness.database,
      name: 'Existing press',
      cardio: false,
      displayUnit: 'kg',
    );
    final initialCount =
        (await harness.database.select(harness.database.exercises).get())
            .length;
    await harness.pump(tester, const ExerciseEditorPage.add());
    for (final name in ['Existing press', ' existing PRESS ']) {
      await tester.enterText(find.bySemanticsLabel('Name'), name);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Exercise already exists'), findsOneWidget);
      expect(find.text('Add exercise'), findsOneWidget);
      expect(
        await harness.database.select(harness.database.exercises).get(),
        hasLength(initialCount),
      );
    }
    await tester.enterText(find.bySemanticsLabel('Name'), 'Another press');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Exercise already exists'), findsNothing);
    expect(
      await harness.database.select(harness.database.exercises).get(),
      hasLength(initialCount + 1),
    );
  });

  testWidgets('AddExercise', (WidgetTester tester) async {
    final harness = await FlexTestHarness.create();
    await harness.pump(tester, const ExerciseEditorPage.add());

    expect(find.text('Add exercise'), findsOne);
    await tester.enterText(find.bySemanticsLabel('Name'), 'Bench press 2');

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Add exercise'), findsNothing);
  });

  testWidgets('new cardio exercise defaults to a distance unit', (
    WidgetTester tester,
  ) async {
    final harness = await FlexTestHarness.create();
    await harness.pump(tester, const ExerciseEditorPage.add());

    expect(find.text('Kilograms (kg)'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(find.text('Kilometers (km)'), findsOneWidget);

    await tester.enterText(find.bySemanticsLabel('Name'), 'Treadmill walking');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final exercise = await (harness.database.select(
      harness.database.exercises,
    )..where((table) => table.name.equals('Treadmill walking'))).getSingle();
    expect(exercise.kind, 'cardio');
    expect(exercise.displayUnit, 'km');
    expect(
      await (harness.database.select(
        harness.database.exerciseSets,
      )..where((set) => set.exerciseId.equals(exercise.id))).get(),
      isEmpty,
    );
  });
}
