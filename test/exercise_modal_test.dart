import 'package:drift/drift.dart' hide isNull;
import 'package:flex/plan/exercise_modal.dart';
import 'package:flex/sets/edit_set_page.dart';
import 'package:flex/database/exercise_set_repository.dart';
import 'package:flex/plan/workout_sessions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../integration_test/support/fixtures.dart';
import 'support/test_app.dart';

Future<(FlexTestHarness, int)> pumpExerciseModal(
  WidgetTester tester, {
  bool recorded = false,
  VoidCallback? onSelect,
}) async {
  final harness = await FlexTestHarness.create();
  final id = await harness.database.plans.insertOne(planFixture());
  final exercise = await ensureExerciseFixture(harness.database, 'Bench press');
  final planExercise = await harness.database.planExercises.insertReturning(
    planExerciseFixture(planId: id, exerciseId: exercise.id),
  );
  final workout = await resumeOrStartWorkout(harness.database, id);

  if (recorded) {
    await insertExerciseSetFixture(
      harness.database,
      exercise.name,
      workoutId: workout.id,
    );
  }
  await harness.pump(
    tester,
    Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            builder: (_) => ExerciseModal(
              planExercise: planExercise,
              exerciseName: exercise.name,
              workoutId: workout.id,
              hasData: true,
              onSelect: onSelect ?? () {},
            ),
          ),
          child: const Text('Open actions'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open actions'));
  await tester.pumpAndSettle();
  return (harness, id);
}

void main() {
  testWidgets(
    'ExerciseModal edit does not crash when exercise has no recorded sets',
    (WidgetTester tester) async {
      await pumpExerciseModal(tester);

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'ExerciseModal undo does not crash when exercise has no recorded sets',
    (WidgetTester tester) async {
      await pumpExerciseModal(tester);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('mobile edit opens the latest saved set', (tester) async {
    await pumpExerciseModal(tester, recorded: true);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.byType(EditSetPage), findsOneWidget);
  });

  testWidgets('mobile undo deletes the saved set and refreshes selection', (
    tester,
  ) async {
    var selected = 0;
    final (harness, _) = await pumpExerciseModal(
      tester,
      recorded: true,
      onSelect: () => selected++,
    );
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(await ExerciseSetQuery(harness.database).get(), isEmpty);
    expect(selected, 1);
    expect(tester.takeException(), isNull);
  });
}
